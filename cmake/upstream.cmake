# 上游接入：libaom（CMake 原生）→ <build>/pkg/prefix，探针链接静态 libaom。

set(PKG_ROOT "${CMAKE_BINARY_DIR}/pkg")
if(NOT DEFINED PKG_PREFIX)
  set(PKG_PREFIX "${PKG_ROOT}/prefix")
  add_custom_target(pkg ALL
    COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/cmake/pkg-build.sh" "${SRC_DIR}" "${PKG_ROOT}"
            "${RVV_MARCH}" "$<IF:$<BOOL:${RVV_KERNELS}>,1,0>"
    COMMENT "构建上游 libaom（${SRC_DIR}）"
    VERBATIM)
  set(HAVE_PKG_TARGET TRUE)
endif()

add_executable(aom_harness test/pkg_aom.c)
if(HAVE_PKG_TARGET)
  add_dependencies(aom_harness pkg)
endif()
target_include_directories(aom_harness PRIVATE "${PKG_PREFIX}/include")
target_link_directories(aom_harness PRIVATE "${PKG_PREFIX}/lib")
target_link_libraries(aom_harness PRIVATE aom pthread m)
target_compile_options(aom_harness PRIVATE ${RVV_FLAGS})

add_test(NAME aom_harness COMMAND aom_harness)
