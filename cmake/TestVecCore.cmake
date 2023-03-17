cmake_minimum_required(VERSION 3.16...3.25)

set(CTEST_PROJECT_NAME "VecCore")

set(ENV{LANG} "C")
set(ENV{LC_ALL} "C")

if(CDASH)
  set(CTEST_DROP_METHOD "http")
  set(CTEST_DROP_SITE "cdash.cern.ch")
  set(CTEST_DROP_LOCATION "/submit.php?project=VecCore")
  set(CTEST_DROP_SITE_CDASH TRUE)
endif()

if(NOT DEFINED CTEST_SITE)
  site_name(CTEST_SITE)
  if(EXISTS "/etc/os-release")
    file(STRINGS "/etc/os-release" OSPN REGEX "^PRETTY_NAME=.*$")
    string(REGEX REPLACE "PRETTY_NAME=\"(.*)\"$" "\\1" DISTRO "${OSPN}")
    string(APPEND CTEST_SITE " (${DISTRO} ${CMAKE_SYSTEM_PROCESSOR})")
  else()
    cmake_host_system_information(RESULT OS_NAME QUERY OS_NAME)
    cmake_host_system_information(RESULT OS_VERSION QUERY OS_VERSION)
    string(APPEND CTEST_SITE " (${OS_NAME} ${OS_VERSION} ${CMAKE_SYSTEM_PROCESSOR})")
  endif()
endif()

cmake_host_system_information(RESULT
  NCORES QUERY NUMBER_OF_PHYSICAL_CORES)
cmake_host_system_information(RESULT
  NTHREADS QUERY NUMBER_OF_LOGICAL_CORES)

if(NOT DEFINED ENV{CMAKE_BUILD_PARALLEL_LEVEL})
  set(ENV{CMAKE_BUILD_PARALLEL_LEVEL} ${NTHREADS})
endif()

if(NOT DEFINED ENV{CTEST_PARALLEL_LEVEL})
  set(ENV{CTEST_PARALLEL_LEVEL} ${NCORES})
endif()

set(CTEST_SOURCE_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}/..")
set(CTEST_BINARY_DIRECTORY "${CTEST_SOURCE_DIRECTORY}/build")

ctest_empty_binary_directory("${CTEST_BINARY_DIRECTORY}")

if(MEMCHECK)
  find_program(CTEST_MEMORYCHECK_COMMAND NAMES valgrind)
endif()

if(DEFINED ENV{CMAKE_GENERATOR})
  set(CTEST_CMAKE_GENERATOR $ENV{CMAKE_GENERATOR})
else()
  execute_process(COMMAND ${CMAKE_COMMAND} --system-information
    OUTPUT_VARIABLE CMAKE_SYSTEM_INFORMATION ERROR_VARIABLE ERROR)
  if(ERROR)
    message(FATAL_ERROR "Could not detect default CMake generator")
  endif()
  string(REGEX REPLACE ".+CMAKE_GENERATOR \"([-0-9A-Za-z ]+)\".*$" "\\1"
    CTEST_CMAKE_GENERATOR "${CMAKE_SYSTEM_INFORMATION}")
endif()

if(NOT DEFINED CTEST_CONFIGURATION_TYPE)
  if(DEFINED ENV{CMAKE_BUILD_TYPE})
    set(CTEST_CONFIGURATION_TYPE $ENV{CMAKE_BUILD_TYPE})
  else()
    set(CTEST_CONFIGURATION_TYPE RelWithDebInfo)
  endif()
endif()

if(DEFINED CTEST_SCRIPT_ARG)
  set(TARGET_ISA ${CTEST_SCRIPT_ARG})
else()
  set(TARGET_ISA Native)
endif()

set(CTEST_BUILD_NAME "${CMAKE_SYSTEM_NAME}")

execute_process(COMMAND ${CMAKE_COMMAND} --system-information
  OUTPUT_VARIABLE CMAKE_SYSTEM_INFORMATION ERROR_VARIABLE ERROR)

if(ERROR)
  message(FATAL_ERROR "Cannot detect system information")
endif()

string(REGEX REPLACE ".+CMAKE_CXX_COMPILER_ID \"([-0-9A-Za-z ]+)\".*$" "\\1"
  COMPILER_ID "${CMAKE_SYSTEM_INFORMATION}")
string(REPLACE "GNU" "GCC" COMPILER_ID "${COMPILER_ID}")

string(REGEX REPLACE ".+CMAKE_CXX_COMPILER_VERSION \"([^\"]+)\".*$" "\\1"
  COMPILER_VERSION "${CMAKE_SYSTEM_INFORMATION}")

string(APPEND CTEST_BUILD_NAME " ${COMPILER_ID} ${COMPILER_VERSION}")
string(APPEND CTEST_BUILD_NAME " ${CTEST_CONFIGURATION_TYPE}")
string(APPEND CTEST_BUILD_NAME " ${TARGET_ISA}")

set(CMAKE_ARGS
  -DBUILD_BENCHMARKS=ON
  -DBUILD_TESTING=ON
  -DBUILD_GOOGLETEST=ON
  -DBUILD_GOOGLEBENCH=ON
  -DBUILD_UMESIMD=${UNIX}
  -DBUILD_VC=${UNIX}
  -DCMAKE_DISABLE_FIND_PACKAGE_PkgConfig=${WIN32}
  -DTARGET_ISA=${TARGET_ISA}
  $ENV{CMAKE_ARGS}
  ${CMAKE_ARGS}
)

ctest_start(Continuous)
ctest_configure(OPTIONS "${CMAKE_ARGS}")
ctest_build()
ctest_test()
ctest_memcheck()

if(CDASH)
  ctest_submit()
endif()
