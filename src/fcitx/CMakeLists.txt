cmake_minimum_required(VERSION 3.21)
project(fcitx5-inlinecompletion VERSION 0.1.0 LANGUAGES CXX)

find_package(Fcitx5Core REQUIRED)
include("${FCITX_INSTALL_CMAKECONFIG_DIR}/Fcitx5Utils/Fcitx5CompilerSettings.cmake")

add_library(inlinecompletion MODULE inlinecompletion.cpp)
target_compile_features(inlinecompletion PRIVATE cxx_std_20)
target_link_libraries(inlinecompletion PRIVATE Fcitx5::Core)
set_target_properties(inlinecompletion PROPERTIES PREFIX "")

install(TARGETS inlinecompletion DESTINATION "${FCITX_INSTALL_LIBDIR}/fcitx5")
install(FILES inlinecompletion.conf DESTINATION "${FCITX_INSTALL_PKGDATADIR}/addon")
