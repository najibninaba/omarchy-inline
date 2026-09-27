cmake_minimum_required(VERSION 3.21)
project(fcitx5-cotypist VERSION 0.1.0 LANGUAGES CXX)

find_package(Fcitx5Core REQUIRED)
include("${FCITX_INSTALL_CMAKECONFIG_DIR}/Fcitx5Utils/Fcitx5CompilerSettings.cmake")

add_library(cotypist MODULE cotypist.cpp)
target_compile_features(cotypist PRIVATE cxx_std_20)
target_link_libraries(cotypist PRIVATE Fcitx5::Core)
set_target_properties(cotypist PROPERTIES PREFIX "")

install(TARGETS cotypist DESTINATION "${FCITX_INSTALL_LIBDIR}/fcitx5")
install(FILES cotypist.conf DESTINATION "${FCITX_INSTALL_PKGDATADIR}/addon")
