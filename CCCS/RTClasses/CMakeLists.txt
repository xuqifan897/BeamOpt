file(GLOB SOURCES *.cpp *.cc *.cxx )
file(GLOB HEADERS *.h *.hpp )

add_library(RTClasses STATIC
    ${SOURCES} ${HEADERS}
    )
target_compile_features(RTClasses PUBLIC cxx_std_11)

target_include_directories(RTClasses PUBLIC
    # necessary for c++ files that use cuda vector types
    ${DCMTK_INCLUDE_DIRS}/
    ${DCMTK_DIR}/include/
    )

link_directories(/data/usr/DCMTK/lib)
target_link_libraries(RTClasses PRIVATE Utilities ${DCMTK_LIBRARIES})


add_executable(anonymize_dicom
    anonymize_dicom.cpp
    rtimages.h
    rtstruct.h
    )
target_compile_features(anonymize_dicom PUBLIC cxx_std_11)
target_link_libraries(anonymize_dicom
    RTClasses
    Utilities
    )
install(TARGETS anonymize_dicom
    RUNTIME DESTINATION bin
    )
