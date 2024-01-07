import os
import numpy as np
import pydicom
import matplotlib.pyplot as plt
from rt_utils import RTStructBuilder

def viewPatient(patFolder):
    dataFolder = os.path.join(patFolder, "data")
    resultFolder = os.path.join(patFolder, "dicomShow")
    rtfile = 'RTstructure.dcm'
    rtFile = os.path.join(dataFolder, rtfile)
    if not os.path.isdir(resultFolder):
        os.mkdir(resultFolder)
    
    rtstruct = RTStructBuilder.create_from(
        dicom_series_path=dataFolder,
        rt_struct_path=rtFile)
    
    ROInames = rtstruct.get_roi_names()
    # # print(ROInames)
    # skinKey = "Lung_Rt"
    # assert skinKey in ROInames
    # mask = rtstruct.get_roi_mask_by_name(skinKey)

    maskDict = {}
    for name in ROInames:
        maskDict[name] = rtstruct.get_roi_mask_by_name(name)

    # sort files
    allFiles = os.listdir(dataFolder)
    allFiles.remove(rtfile)
    allFiles = [(a, getIdx(a)) for a in allFiles]
    allFiles.sort(key = lambda a: a[1])
    allFiles = [a[0] for a in allFiles]
    nSlices = len(allFiles)

    allColors = plt.colormaps()

    if False:
        # draw slices
        for i in range(nSlices):
            file = allFiles[i]
            file = os.path.join(dataFolder, file)
            sliceArray = pydicom.dcmread(file).pixel_array
            
            plt.imshow(sliceArray, cmap='gray')
            maskIdx = nSlices - i - 1
            legendList = []
            
            count = 0
            for key, value in maskDict.items():
                maskSlice = value[:, :, maskIdx]
                maskSum = np.sum(maskSlice)
                if (maskSum == 0):
                    continue
                plt.contour(maskSlice, levels=[0.5], linewidths=1, colors=allColors[count])
                count += 1
                legendList.append(key)
            plt.legend(legendList)
            figureFile = os.path.join(resultFolder, '{:03d}.png'.format(i+1))
            plt.savefig(figureFile)
            plt.clf()
            print("Slice: {}".format(i+1))
    
    if True:
        # get body mask information
        maskVolume = [(a, np.sum(b)) for a, b in maskDict.items()]
        maskVolume.sort(key = lambda a: a[1])
        print(maskVolume)


def getIdx(fileName):
    idx_str = fileName.split('.')[-2]
    return int(idx_str)


def viewColor():
    color_maps_list = plt.colormaps()
    print(color_maps_list)


if __name__ == '__main__':
    viewPatient("/data/qifan/FastDoseWorkplace/BOOval/HN02")