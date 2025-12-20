cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)
apply_standard_settings(${BINARY_NAME})
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")
add_dependencies(${BINARY_NAME} flutter_assemble)

# Copy Argox printer DLLs to the executable directory (for Debug builds)
# The DLL is in the parent package's windows folder: argox_printer/windows/
add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E echo "Copying Argox DLLs for Debug build..."
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${CMAKE_CURRENT_SOURCE_DIR}/../../../windows/Winppla.dll"
    "$<TARGET_FILE_DIR:${BINARY_NAME}>"
  COMMAND ${CMAKE_COMMAND} -E echo "Argox DLLs copied to $<TARGET_FILE_DIR:${BINARY_NAME}>"
  VERBATIM
)

# Copy Argox printer DLLs to the executable directory (for Release builds)
install(CODE "
  file(GLOB ARGOX_DLLS \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}/packages/argox_printer/windows/*.dll\")
  if(ARGOX_DLLS)
    file(COPY \${ARGOX_DLLS} DESTINATION \"${INSTALL_BUNDLE_LIB_DIR}/..\")
    message(STATUS \"Copied Argox DLLs to executable directory\")
  endif()
  " COMPONENT Runtime)
