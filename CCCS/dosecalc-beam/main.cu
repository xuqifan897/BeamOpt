/* This file contains Cuda runtime calls (cuda*****()) and must be compiled directly using nvcc.
*  Extension .cu ensures this is handled by cmake automatically
*/

// header file includes
#include <cstring> // memset()
#include <stdio.h>
#include <string>

#include <boost/filesystem.hpp>

// cuda multithreading helpers
#include "./multithreading.h"

// basic utility classes
#include "Utilities/logging.h"
#include "Utilities/timing.h"

#include "CudaUtilities/manage_gpu.cuh"
#include "dosecalc_defs.h"
#include "DoseCalcIO/dosecalcio.h"
#include "version.h"

// kernel code is organized using standard c++ code/header organization. *_host.cu contains host program
// callable functions and data structures that must be accessible directly by host code (this module).
// *_host.cuh contains function and data declarations to be included by host code
// _device.cu/.cuh contain kernels and kernel forward declarations as well as data structures that should be
// accessible only from device code and calling functions in *_host.cu
#include "nvbbRayConvolve_host.cu"
#include "server/brain_defs.h"  // dosecalc data container structs

bool extra_verbose = false; // print findBEV verbose output
bool extra_debug = false;    // print between-kernel-execution data structures (dose, terma, density)

CONSTANTS*   constants;
BEAM* device_beam_arr[MAXIMUM_DEVICE_COUNT];
MONO_KERNELS mono_kernels;
void* tworker_radConvolveTexture(void* args) {
    // cast args to struct
    DEVICE_THREAD_DATA* tdata = (DEVICE_THREAD_DATA *)(args);

    // set device number
    if (tdata->verbose) {
        printf("New thread spawned, setting device to: %d\n", tdata->gpuid);
    }
    checkCudaErrors(cudaSetDevice(tdata->gpuid));

    /////////////////////// RUN CONVOLUTIONS
    // each thread executes its device in parallel
    // int threadid = 0; // DEBUG
    radconvolveTexture(
            &mono_kernels,
            constants,
            tdata->device_beam_arr,
            tdata->device_nbeams,
            tdata->nrays,
            tdata->deviceid,
            tdata->gpuid,
            tdata->verbose,
            tdata->timing,
            tdata->debugwrite
            );
    // wait for all processes on this GPU to complete
    checkCudaErrors( cudaDeviceSynchronize() );
    return nullptr;
}

int main(int argc, char *argv[])
{
    Logger logger; // standard stdout printing
    AutoTimer timer_total;
    AutoTimer timer_task;

	// flags and variable definitions
    bool verbose = false;
    bool timing  = false;
    bool debugwrite = false;

    float *dose; // host array for final summed dose

	// output usage if prompted by -help (-h) command line flag
    if (checkCmdLineFlag( argc, (const char**)argv, "help" )) {
        printf("dosecalc-beam (v%s):\n"
               "  a full-beam, general purpose, multi-GPU dose calculation engine designed\n"
               "  to provide efficient evaluation of final dose distributions from customizable\n"
               "  fluence map specifications.\n\n", VERSION_STRING);
        printf("Usage:  dosecalc-beam [options...]\n");
        printf(" Optional Args:\n");
        printf("  --out=[outfile]      name of result file\n");
        printf("  --ndevices=[<int>]   maximum number of GPUs to employ\n");
        printf("  --device=[<int>]     device ID for first GPU\n");
        printf("  --verbose[-extra]    output calculation progress information\n");
        printf("  --timing             output calculation timing information\n");
        /* printf("  --debug[-extra]      save debug volumes\n"); */
        printf("  --help               show this help message\n");
        exit(EXIT_FAILURE);
    }

	// check and set flags
    if (checkCmdLineFlag( argc, (const char**)argv, "verbose" )) {
        verbose = true;
    }
    if (checkCmdLineFlag( argc, (const char**)argv, "verbose-extra" )) {
        verbose = extra_verbose = true;
    }
    if (checkCmdLineFlag( argc, (const char**)argv, "timing" )) {
        timing = true;
    }
    if (checkCmdLineFlag( argc, (const char**)argv, "debug" )) {
        debugwrite = true;
    }
    if (checkCmdLineFlag( argc, (const char**)argv, "debug-extra" )) {
        debugwrite = extra_debug = true;
    }

///////////////////////// LOAD PRE COMPUTED DATA (from omni-precomp)
    // holds beam delivery / convolution / data volume information
    constants = new CONSTANTS{};

    // holds 3D data volumes for convolution calculation (terma, density, kernels)
    SHM_DATA* datavols = new SHM_DATA{};

    logger.print_head("LOADING DATA");

    // this data is generated by the mgcs-omni-precomp script and stored locally
    // will need to be updated to calculate on demand per beam geometry
    if ( load_omni_header( constants, verbose ) < 0) {
        printf("\n Failed to load header data.\n");
        delete constants;
        return -1;
    }
    if ( load_data( constants, datavols, verbose ) < 0) {
        printf("\n Failed to mmap pre-computed data.\n");
        delete constants;
        return -1;
    }


//////////////////////////// PARSE INPUTS
    std::ostringstream full_h5_fname;
    {
        char* c_outfile;
        if (getCmdLineArgumentString(argc, (const char**)argv, "out", &c_outfile)) {
            full_h5_fname << std::string(c_outfile);
        } else {
            if (!dcio::dir_exists(RESULTS_DIR)) {
                dcio::create_directory(RESULTS_DIR);
            }
            full_h5_fname << RESULTS_DIR << "/Dose.h5";
        }
        /* if (dcio::is_unqualified(outfile)) { */
        /*     if (!dcio::dir_exists(RESULTS_DIR)) { */
        /*         dcio::create_directory(RESULTS_DIR); */
        /*     } */
        /*     full_h5_fname << RESULTS_DIR << "/" << outfile << ".h5"; */
        /* } else { full_h5_fname << outfile << ".h5"; } */
    }

    int nrays = constants->nphi * (constants->ntheta / 2);  // convolution directions per beamlet

    // number of GPUs to be utilized by this server
    int ndev_requested = DEFAULT_DEVICE_COUNT;
    if (checkCmdLineFlag( argc, (const char**)argv, "ndevices" )) {
        ndev_requested = getCmdLineArgumentInt( argc, (const char**)argv, "ndevices");
    }

	// sets the device ID for the first GPU
	// when using multiple GPUs, the subsequent device IDs will be incremented from this
    int DEVICE = 0;
    if (checkCmdLineFlag( argc, (const char**)argv, "device" )) {
        DEVICE = getCmdLineArgumentInt( argc, (const char**)argv, "device");
    }

	// automatically load the omni-beam-list generated by the precompution script
	// function defined in "../mgcs-brain/io_functions.h"
    BEAM* beam_arr = new BEAM[constants->beam_count];

    if ( load_omni_beam_list( beam_arr, constants->beam_count, verbose ) < 0 ) {
        printf("\n Failed to load beam list.\n");
        delete [] beam_arr;
        return -1;
    }
    // limit ndevices to nbeams
    if ((int)constants->beam_count < ndev_requested) {
        ndev_requested = constants->beam_count;
    }

	// load spectrum files
    mono_kernels.spectrum_file = std::string(constants->beam_spec);

    //monoenergetic kernel file
    //spectrum data
    if ( (1 != read_spectrum_file(&mono_kernels,verbose)) ) {
        printf("Failed reading spectrum file!\n");
        exit(1);
    }
    //read all monoenergetic kernels that were specified in spectrum file
    for (int i=0; i<mono_kernels.nkernels; i++) {
        if ( (1 != read_kernel(&(mono_kernels.kernel[i]))) ) {
            printf("Failed reading kernel!\n");
            exit(1);
        }
    }

    if (timing) {
        timer_task.restart_print_time_elapsed("Read_Specfile & Data Prep");
    }

    logger.print_tail();

////////////////////////////// INITIALIZE CUDA DEV ////////////////////////////////////
    logger.print_head("DEVICE SUMMARY");
    int ndevices = 0;
    int ndev = 0;
    int gpuid_arr[MAXIMUM_DEVICE_COUNT] = {0};
    /* init_devices_uva(ndev_uva, gpuid_arr, MAXIMUM_DEVICE_COUNT, ndev_requested, DEVICE, verbose); */
    init_devices(ndev, gpuid_arr, MAXIMUM_DEVICE_COUNT, ndev_requested, DEVICE, verbose);

    // ndev should always contain the ACTUAL number of devices being used for execution
    if (ndev == 1) {
        printf("Using 1 Device\n");
        ndevices = 1;
    }
    else if (ndev_requested < ndev) {
        printf("%d Devices, but only using %d as requested.\n", ndev, ndev_requested);
        ndevices = ndev_requested;
    } else {
        printf("Using %d Devices.\n", ndev);
        ndevices = ndev;
    }

    if (timing) {
        std::cout << std::endl;
        timer_task.restart_print_time_elapsed("Device initialization");
    }
    logger.print_tail();

////////////////////////////// ASSIGN BEAMS TO DEVICES ////////////////////////////////////
	// determine how many convolutions each GPU will perform
    // TODO: convert all dynamic mem allocations to Vector types with automatic destruction
    int device_nbeams[MAXIMUM_DEVICE_COUNT] = {0}; // total nbeams for this GPU
    int _assigned_beams = 0; // total nbeams assigned
    for (int i=0; i<ndevices; i++) {
        int _nbeams = constants->beam_count / ndevices;
        device_nbeams[i] = _nbeams;
        _assigned_beams += _nbeams;
    }
    //assign leftovers, distributed among all devices
    int _beams_left = constants->beam_count - _assigned_beams;
    for (int k=0; k<_beams_left; k++) {
        ++device_nbeams[k];
    }
    // store device specific beams into device specific arrays
    // note: array of pointers is used (rows are static, cols are dynamic)
    int beam_idx = 0;
    for (int i=0; i<ndevices; i++) {
        device_beam_arr[i] = new BEAM[ device_nbeams[i] ];
        for (int j=0; j<device_nbeams[i]; j++) {
            device_beam_arr[i][j] = beam_arr[beam_idx++];
        }
    }

    if (verbose){
        logger.print_head("BEAM ASSIGNMENTS");
        for (int i=0; i<ndevices; i++ ) {
            int gpuid = gpuid_arr[i];
            printf("GPU %d: has %d beams assigned:\n", gpuid, device_nbeams[i]);
            for (int j=0; j<device_nbeams[i]; j++) {
                std::cout << "   beam " << (j+1) << ": " << device_beam_arr[i][j] << std::endl;
            }
            std::cout << std::endl;
        }
        logger.print_tail();
    }
    logger.print_head("PROBLEM DIVISION SUMMARY");
    printf("%3d NVB directions per beam\n", nrays);
    printf("%3d devices for server\n", ndevices);
    printf("%3d beams per device (max)\n", device_nbeams[0]);
    logger.print_tail();

////////////////////////////// INITIALIZE DEVICE MEMORY AND TEXTURES ////////////////////////////////////
    logger.print_head("MEMORY INITIALIZATION");

    // Store copies of constant problem data and texture/surface references on each GPU
    for (int i=0; i<ndevices; i++) {
        int gpuid = gpuid_arr[i];
        std::cout << "Initializing memory on GPU: " << gpuid << std::endl;
        checkCudaErrors(cudaSetDevice(gpuid));
        initCudaConstandTex(
                datavols,
                &mono_kernels,
                constants,
                nrays,
                i,
                gpuid,
                verbose,
                timing,
                debugwrite
                );
        std::cout << std::endl;
    }

    if (timing) {
        std::cout << std::endl;
        timer_task.restart_print_time_elapsed("GPU initialization");
    }
    logger.print_tail();

////////////////////////////// DOSE CONVOLUTION ////////////////////////////////////
    logger.print_head("DOSE CONVOLUTION");

    // using CUTThread library for portability between windows and linux
    CUTThread* dev_threads = new CUTThread[ndevices];
    DEVICE_THREAD_DATA** tdata = new DEVICE_THREAD_DATA*[ndevices];
    for (int i=0; i<ndevices; i++) {
        int gpuid = gpuid_arr[i];

        // initialize thread data
        tdata[i] = new DEVICE_THREAD_DATA();  // zero initialize dynamically allocated struct

        tdata[i]->device_beam_arr = device_beam_arr[i];
        tdata[i]->device_nbeams   = device_nbeams[i];
        tdata[i]->nrays           = nrays;
        tdata[i]->deviceid        = i;
        tdata[i]->gpuid           = gpuid;
        tdata[i]->verbose         = verbose;
        tdata[i]->timing          = timing;
        tdata[i]->debugwrite      = debugwrite;

        // create thread and execute worker
        dev_threads[i] = cutStartThread(tworker_radConvolveTexture, (void*) tdata[i]);
    }

    // join cpu threads
    cutWaitForThreads(dev_threads, ndevices);
    // cleanup thread data
    delete [] dev_threads;
    for (int i=0; i<ndevices; i++) {
        delete tdata[i];
    }
    delete [] tdata;

    if (timing) {
        std::cout << std::endl;
        timer_task.restart_print_time_elapsed("Convolution");
    }
    logger.print_tail();

    // allocate host pagelocked/pinned memory for faster HtoD/DtoH memcopies
    checkCudaErrors( cudaMallocHost( (void**)&dose, datavols->size_data * sizeof(float) ) );

    ///////////////////////////// END FORK
    // parent process sums results from each threaded GPU
    // sum dose results from all GPUs - each GPU already has one dose volume with sum of all its assigned beam doses
    // TODO: Should convert this to inline batched summation when more beams are requested than can be
    // simultaneously stored in device memory
    // TODO: could potentially stage all beam-specific dose volumes to host RAM then perform batched GPU summation
    // after all beam doses are calculated
    cuda_sum_device_float_dose(
            dose,      // summed dose output
            ndevices,
            constants,
            timing,
            verbose
            );

    if (timing) {
        std::cout << std::endl;
        timer_task.restart_print_time_elapsed("Dose summation");
    }
    /////////////////////////////////

    char dose_label[32];

    std::string outpath = full_h5_fname.str();
    boost::filesystem::create_directories(boost::filesystem::path(outpath).parent_path());
    sprintf(dose_label,"%s/%s.raw", boost::filesystem::path(outpath).parent_path().c_str(), boost::filesystem::path(outpath).stem().c_str());
    write_binary_data<float>( dose, constants->size, dose_label, true);
    FrameOfReference frame{constants->size, constants->start, constants->voxel};
    Volume<float>::writeToFile(outpath, dose, frame);
    std::cout << "Data written to \""<<outpath<<"\""<<std::endl;

    /////////////////////////////////
    if (timing) {
        std::cout << std::endl;
        timer_task.stop_print_time_elapsed("Dose File Write");
        timer_total.stop_print_time_elapsed("Full Program Execution");
    }

    checkCudaErrors( cudaFreeHost( dose ) );

    // clean up GPU(s)
    freeCudaTexture(ndevices, gpuid_arr);
    for (int deviceid=0; deviceid<ndevices; deviceid++) {
        checkCudaErrors( cudaSetDevice(gpuid_arr[deviceid]) );
        checkCudaErrors( cudaDeviceReset() );
    }
    free_data(constants, datavols); // unmap files from memory
    for (int deviceid=0; deviceid<ndevices; deviceid++) {
        delete [] device_beam_arr[deviceid];
    }
    delete [] beam_arr; // can probaly be done right after assigning beams since all structs are copied;
    delete datavols;
    delete constants;

    logger.print_tail();
    if (timing) {
        timer_total.stop_print_time_elapsed("Full Program Execution");
    }

    return 0;
}


