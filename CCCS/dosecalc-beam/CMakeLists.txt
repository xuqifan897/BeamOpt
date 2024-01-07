add_executable(dosecalc-beam
    main.cu
    )
target_compile_features(dosecalc-beam PUBLIC cxx_std_11)
set_target_properties(dosecalc-beam PROPERTIES CUDA_SEPARABLE_COMPILATION ON)

target_include_directories(dosecalc-beam
    PRIVATE
    ${Boost_INCLUDE_DIR})

target_link_libraries(dosecalc-beam
    Utilities
    DoseCalcIO
    DoseCalcAlgo
    CudaUtilities
    boost_filesystem
    -lpthread
    )

install(TARGETS dosecalc-beam
        RUNTIME DESTINATION bin
        )
