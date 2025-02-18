##*****************************************************************//
##    Albany 3.0:  Copyright 2016 Sandia Corporation               //
##    This Software is released under the BSD license detailed     //
##    in the file "license.txt" in the top-level Albany directory  //
##*****************************************************************//

cmake_minimum_required(VERSION 3.17.0)

if (CMAKE_VERSION VERSION_GREATER_EQUAL 3.27)
  cmake_policy (SET CMP0144 NEW)
endif()

# Add path where we keep some CMake utils to cmake search path
list (APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake)

# Set Albany branch and commit id
EXECUTE_PROCESS(
  COMMAND git rev-parse --abbrev-ref HEAD
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
  OUTPUT_VARIABLE ALBANY_GIT_BRANCH
  OUTPUT_STRIP_TRAILING_WHITESPACE
)
EXECUTE_PROCESS(
  COMMAND git log -1 --format=%h
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
  OUTPUT_VARIABLE ALBANY_GIT_COMMIT_ID
  OUTPUT_STRIP_TRAILING_WHITESPACE
)

message("\n +-----------------------------------------")
message(" |       Albany version details:")
message(" +-----------------------------------------")
message(" |  ALBANY_GIT_BRANCH = ${ALBANY_GIT_BRANCH}")
message(" |  ALBANY_GIT_COMMIT_ID = ${ALBANY_GIT_COMMIT_ID}")
message(" +-----------------------------------------\n")

# If user doesn't specify a build type, we assume production (i.e., RELEASE)
if (NOT CMAKE_BUILD_TYPE)
  set (CMAKE_BUILD_TYPE RELEASE CACHE STRING "Build type for Albany (default to Trilinos)")
endif()

project(Albany CXX C)

include(CMakePackageConfigHelpers)
include(GNUInstallDirs)
message("\n +----------------------------------+")
message(" |    Albany Installation details   |")
message(" +----------------------------------+")
message(" | - Prefix: ${CMAKE_INSTALL_PREFIX}")
message(" | - Binaries dir: ${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_BINDIR}")
message(" | - Headers dir: ${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_INCLUDEDIR}")
message(" | - Libraries dir: ${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}")
message(" +----------------------------------+\n")


# Kokkos recommends to set CMAKE_CXX_EXTENSIONS to OFF
set(CMAKE_CXX_EXTENSIONS OFF)

# Get Trilinos as one entity
set (ALBANY_TRILINOS_DIR "" CACHE STRING "Location of the Trilinos installation folder")
if (ALBANY_TRILINOS_DIR)
  list(PREPEND CMAKE_PREFIX_PATH ${ALBANY_TRILINOS_DIR})
endif()
message ("-- Looking for trilinos installation ...")
message ("     ALBANY_TRILINOS_DIR: ${ALBANY_TRILINOS_DIR}") 
find_package(Trilinos 16.1 REQUIRED)
message("-- Looking for trilinos installation ... Found.\n")

# Trilinos_BIN_DIRS probably should be defined in the Trilinos config. Until it is, set it here.
# This is needed to find SEACAS tools used during testing (epu, etc).
SET(Trilinos_BIN_DIR "${Trilinos_INSTALL_DIR}/bin")
# Set Trilinos commit id
IF(EXISTS "${Trilinos_INSTALL_DIR}/TrilinosRepoVersion.txt")
  FILE(STRINGS "${Trilinos_INSTALL_DIR}/TrilinosRepoVersion.txt" TRILINOS_VERSION_FILE)
  SET(TRILINOS_GIT_COMMIT_ID_LINE_LOC 1)
  LIST(GET TRILINOS_VERSION_FILE ${TRILINOS_GIT_COMMIT_ID_LINE_LOC} TRILINOS_GIT_COMMIT_ID_LINE)
  STRING(REGEX MATCH "^[^ ]+" Trilinos_GIT_COMMIT_ID ${TRILINOS_GIT_COMMIT_ID_LINE})
  SET(ALBANY_TRILINOS_GIT_COMMIT_ID ${Trilinos_GIT_COMMIT_ID})
ELSE ()
  SET(ALBANY_TRILINOS_GIT_COMMIT_ID "UNKOWN")
ENDIF()

IF(Kokkos_ENABLE_OPENMP)
  MESSAGE("-- Kokkos is configured to use OpenMP, Albany will also.")
ENDIF()
IF(Kokkos_ENABLE_CUDA)
  MESSAGE("-- Kokkos is configured to use CUDA, Albany will also.")
  IF(Kokkos_ENABLE_CUDA_UVM)
    MESSAGE("-- Kokkos is configured to use CUDA UVM, Albany will also.")
  ENDIF()
ENDIF()

message("+-----------------------------------------")
message("|     Trilinos installation details")
message("+-----------------------------------------")
message("|  Trilinos_DIR: ${Trilinos_DIR}")
message("|  Trilinos_CMAKE_BUILD_TYPE: ${Trilinos_CMAKE_BUILD_TYPE}")
message("|  Trilinos_VERSION: ${Trilinos_VERSION}")
message("|  Trilinos_GIT_COMMIT_ID: ${Trilinos_GIT_COMMIT_ID}")
message("|  Trilinos_BIN_DIR: ${Trilinos_BIN_DIR}")
message("|  Trilinos_BUILD_SHARED_LIBS: ${Trilinos_BUILD_SHARED_LIBS}")
message("|  Kokkos executions spaces:")
message("|    Kokkos_ENABLE_SERIAL: ${Kokkos_ENABLE_SERIAL}")
message("|    Kokkos_ENABLE_OpenMP: ${Kokkos_ENABLE_OPENMP}")
message("|    Kokkos_ENABLE_CUDA: ${Kokkos_ENABLE_CUDA}")
message("|    Kokkos_ENABLE_HIP: ${Kokkos_ENABLE_HIP}")
message("+-----------------------------------------\n")

OPTION (ALBANY_SUPPRESS_TRILINOS_WARNINGS "Whether or not Trilinos headers should be treated as 'system' headers (hence, without issuing warnings)" ON)

# Build Albany as shared libraries if Trilinos was compiled that way
IF(Trilinos_BUILD_SHARED_LIBS)
  if (DEFINED BUILD_SHARED_LIBS AND NOT BUILD_SHARED_LIBS)
    message ("User requested STATIC libs, but Trilinos was built with SHARED libraries.")
    message ("  -> Do NOT set BUILD_SHARED_LIBS in your configure script.")
    message (FATAL_ERROR "Aborting.")
  endif()
  SET(Albany_LIBRARY_TYPE SHARED)
  SET(BUILD_SHARED_LIBS ON)
  MESSAGE("-- Building Albany with SHARED libraries")
ELSE(Trilinos_BUILD_SHARED_LIBS)
  if (DEFINED BUILD_SHARED_LIBS AND BUILD_SHARED_LIBS)
    message ("User requested SHARED libs, but Trilinos was built with STATIC libraries.")
    message ("  -> Do NOT set BUILD_SHARED_LIBS in your configure script.")
    message (FATAL_ERROR "Aborting.")
  endif()
  SET(Albany_LIBRARY_TYPE STATIC)
  SET(BUILD_SHARED_LIBS OFF)
  MESSAGE("-- Building Albany with STATIC libraries")
ENDIF(Trilinos_BUILD_SHARED_LIBS)

OPTION(Albany_BUILD_STATIC_EXE "Flag to turn on building of static executables in Albany" OFF)
IF(NOT BUILD_SHARED_LIBS AND Albany_BUILD_STATIC_EXE)
  MESSAGE("-- Building Albany with static executables")
ENDIF(NOT BUILD_SHARED_LIBS AND Albany_BUILD_STATIC_EXE)

# Option to turn on and off deprecation warnings
OPTION(Albany_DEPRECATED_DECLARATIONS "Flag to turn on warnings for deprecated code" ON)
IF (Albany_DEPRECATED_DECLARATIONS)
  SET(ALBANY_ENABLE_DEPRECATED ON)
  MESSAGE("-- Deprecated code warnings Enabled")
ELSE()
  MESSAGE("-- Deprecated code warnings are NOT Enabled.")
ENDIF()

# AGS: Adding these lines so Ctest can be run to submit to cdash dashboard
#   Uses CTestConfig.cmake file for Cdash info.
enable_testing()
option(BUILD_TESTING "" OFF) # Avoid creating folder "Testing" at config time
include(CTest)

## Check for some required Trilinos package dependencies (Piro, Phalanx) ##
MESSAGE("Checking Trilinos build for required and optional packages")

OPTION(ENABLE_ALBANY_PYTHON "Flag to turn on building of code depending on Python" OFF)
OPTION(ENABLE_PARALLEL_EXODUS "Flag to turn on/off parallel Exodus" ON)

###############################
### Check REQUIRED packages ###
###############################

MESSAGE ("\n  **********************************")
MESSAGE ("  *** Required Trilinos Packages ***")
MESSAGE ("  **********************************\n")
# Piro
LIST(FIND Trilinos_PACKAGE_LIST Piro Piro_List_ID)
IF (Piro_List_ID GREATER -1)
  MESSAGE("-- Looking for Piro ...                          Found.")
ELSE()
  MESSAGE("-- Looking for Piro ...                      NOT Found.")
  MESSAGE(FATAL_ERROR "Albany REQUIRES Piro. Please, configure Trilinos with guidance from trilinos-cmake script in doc directory.")
ENDIF()

# Panzer (new blocked data structures use Panzer DOF manager
LIST(FIND Trilinos_PACKAGE_LIST PanzerDofMgr Panzer_List_ID)
IF (Panzer_List_ID GREATER -1)
  MESSAGE("-- Looking for PanzerDofMgr ...                  Found.")
ELSE()
  MESSAGE("-- Looking for PanzerDofMgr ...              NOT Found.")
  MESSAGE(FATAL_ERROR "Albany REQUIRES PanzerDofMgr. Please, configure Trilinos with guidance from trilinos-cmake script in doc directory.")
ENDIF()

# Phalanx
LIST(FIND Trilinos_PACKAGE_LIST Phalanx Phalanx_List_ID)
IF (Phalanx_List_ID GREATER -1)
  MESSAGE("-- Looking for Phalanx ...                       Found.")
ELSE()
  MESSAGE("-- Looking for Phalanx ...                   NOT Found.")
  MESSAGE(FATAL_ERROR "Albany REQUIRES Phalanx. Please, configure Trilinos with guidance from trilinos-cmake script in doc directory.")
ENDIF()

# NOX
LIST(FIND Trilinos_PACKAGE_LIST NOX NOX_List_ID)
IF (NOX_List_ID GREATER -1)
  MESSAGE("-- Looking for NOX ...                           Found.")
ELSE()
  MESSAGE("-- Looking for NOX ...                       NOT Found.")
  MESSAGE(FATAL_ERROR "Albany REQUIRES NOX. Please, configure Trilinos with guidance from trilinos-cmake script in doc directory.")
ENDIF()

# ThyraTpetraAdapters
LIST(FIND Trilinos_PACKAGE_LIST ThyraTpetraAdapters ThyraTpetraAdapters_List_ID)
IF (ThyraTpetraAdapters_List_ID GREATER -1)
  MESSAGE("-- Looking for ThyraTpetraAdapters ...           Found.")
ELSE()
  MESSAGE("-- Looking for ThyraTpetraAdapters ...       NOT Found.")
  MESSAGE(FATAL_ERROR "Albany REQUIRES ThyraTpetraAdapters. Please, configure Trilinos with guidance from trilinos-cmake script in doc directory.")
ENDIF()

# Intrepid2
LIST(FIND Trilinos_PACKAGE_LIST Intrepid2 Intrepid2_List_ID)
IF (Intrepid2_List_ID GREATER -1)
  MESSAGE("-- Looking for Intrepid2 ...                     Found.")
ELSE()
  MESSAGE("-- Looking for Intrepid2 ...                 NOT Found.")
  MESSAGE(FATAL_ERROR "Albany REQUIRES Intrepid2. Please, configure Trilinos with guidance from trilinos-cmake script in doc directory.")
ENDIF()

# Tempus
LIST(FIND Trilinos_PACKAGE_LIST Tempus Tempus_List_ID)
IF (Tempus_List_ID GREATER -1)
  MESSAGE("-- Looking for Tempus ...                        Found.")
  SET(ALBANY_TEMPUS TRUE)
ELSE()
  MESSAGE("-- Looking for Tempus ...                    NOT Found.")
  MESSAGE(FATAL_ERROR "Albany REQUIRES Tempus. Please, configure Trilinos with guidance from trilinos-cmake script in doc directory.")
ENDIF()

# stk
LIST(FIND Trilinos_PACKAGE_LIST STK have_stk_List_ID)
IF (have_stk_List_ID GREATER -1)
  MESSAGE("-- Looking for stk ...                           Found.")

ELSE()
  MESSAGE("-- Looking for stk ...                       NOT Found.")
  MESSAGE(FATAL_ERROR "Albany REQUIRES stk. Please, configure Trilinos with guidance from trilinos-cmake script in doc directory.")
ENDIF()

###############################
### Check OPTIONAL packages ###
###############################

MESSAGE ("\n  **********************************")
MESSAGE ("  *** Optional Trilinos Packages ***")
MESSAGE ("  **********************************\n")
### Check for some OPTIONAL trilinos packages, which set DEFINES in Alany build ###

# set optional dependency on Panzer's ExprEval subpackage
LIST (FIND Trilinos_PACKAGE_LIST PanzerExprEval PanzerExprEval_List_ID)
IF (PanzerExprEval_List_ID GREATER -1)
  MESSAGE("-- Looking for PanzerExprEval ...                Found.")
  SET(ALBANY_PANZER_EXPR_EVAL TRUE)
ELSE ()
  MESSAGE("-- Looking for PanzerExprEval ...            NOT Found.")
  SET(ALBANY_PANZER_EXPR_EVAL FALSE)
ENDIF()

#set optional dependency on STKExprEval
LIST(FIND Trilinos_PACKAGE_LIST STKExprEval STKExprEval_List_ID)
IF (STKExprEval_List_ID GREATER -1)
  MESSAGE("-- Looking for STKExprEval ...                   Found.")
  SET(ALBANY_STK_EXPR_EVAL TRUE)
  add_definitions(-DALBANY_STK_EXPR_EVAL)
ELSE()
  MESSAGE("-- Looking for STKExprEval ...               NOT Found.")
  SET(ALBANY_STK_EXPR_EVAL FALSE)
ENDIF()

# set optional dependency on Zoltan, for partitioning
# MESSAGE("-- Looking for Zoltan:")
LIST(FIND Trilinos_PACKAGE_LIST Zoltan Zoltan_List_ID)
IF (Zoltan_List_ID GREATER -1)
  SET(ALBANY_ZOLTAN TRUE)
  SET(ALBANY_STK_REBALANCE TRUE)
  MESSAGE("-- Looking for Zoltan ...                        Found.")
ELSE()
  MESSAGE("-- Looking for Zoltan ...                    NOT Found.")
  SET(ALBANY_ZOLTAN FALSE)
  SET(ALBANY_STK_REBALANCE FALSE)
ENDIF()

# set optional dependency on Stokhos, for KL expansions
# MESSAGE("-- Looking for Stokhos:")
LIST(FIND Trilinos_PACKAGE_LIST Stokhos Stokhos_List_ID)
IF (Stokhos_List_ID GREATER -1)
  SET(ALBANY_STOKHOS TRUE)
  MESSAGE("-- Looking for Stokhos ...                       Found.")
ELSE()
  MESSAGE("-- Looking for Stokhos ...                   NOT Found.")
  SET(ALBANY_STOKHOS FALSE)
ENDIF()

# set optional dependency on Amesos2, for solving and preconditioning
LIST(FIND Trilinos_PACKAGE_LIST Amesos2 Amesos2_List_ID)
IF (Amesos2_List_ID GREATER -1)
  MESSAGE("-- Looking for Amesos2 ...                       Found.")
  SET(ALBANY_AMESOS2 TRUE)
  IF (Amesos2_ENABLE_SuperLUDist)
    MESSAGE("-- Looking for Amesos2 SuperLUDist...            Found.")
    SET(ALBANY_AMESOS2_SUPERLUDIST TRUE)
  ELSE()
    MESSAGE("-- Looking for Amesos2 SuperLUDist...        Not Found.")
    SET(ALBANY_AMESOS2_SUPERLUDIST FALSE)
  ENDIF()

  IF (Amesos2_ENABLE_SuperLU)
    MESSAGE("-- Looking for Amesos2 SuperLU...                Found.")
    SET(ALBANY_AMESOS2_SUPERLU TRUE)
  ELSE()
    MESSAGE("-- Looking for Amesos2 SuperLU...            Not Found.")
    SET(ALBANY_AMESOS2_SUPERLU FALSE)
  ENDIF()
  # We can't rely on Amesos2_TPL_LIST any longer; KLU2 and Basker are not
  # TPLs. These will soon be enabled by default in Amesos2. So we'll just
  # assume we have a coarse direct solver.
  SET(ALBANY_AMESOS2_OPERATIONAL_SOLVER TRUE)
ELSE()
  MESSAGE("-- Looking for Amesos2 ...                   NOT Found.")
  SET(ALBANY_AMESOS2 FALSE)
  SET(ALBANY_AMESOS2_OPERATIONAL_SOLVER FALSE)
ENDIF()

# set optional dependency on Ifpack2, for preconditioning
LIST(FIND Trilinos_PACKAGE_LIST Ifpack2 Ifpack2_List_ID)
IF (Ifpack2_List_ID GREATER -1)
  MESSAGE("-- Looking for Ifpack2 ...                       Found.")
  SET(ALBANY_IFPACK2 TRUE)
ELSE()
  MESSAGE("-- Looking for Ifpack2 ...                   NOT Found.")
  SET(ALBANY_IFPACK2 FALSE)
ENDIF()

# set optional dependency on Teko, for preconditioning
LIST(FIND Trilinos_PACKAGE_LIST Teko Teko_List_ID)
IF (Teko_List_ID GREATER -1)
  MESSAGE("-- Looking for Teko ...                          Found.")
  SET(ALBANY_TEKO TRUE)
ELSE()
  MESSAGE("-- Looking for Teko ...                      NOT Found.")
  SET(ALBANY_TEKO FALSE)
ENDIF()

# set optional dependency on MueLu, for preconditioning
LIST(FIND Trilinos_PACKAGE_LIST MueLu MueLu_List_ID)
IF (MueLu_List_ID GREATER -1)
  MESSAGE("-- Looking for MueLu ...                         Found.")
  SET(ALBANY_MUELU TRUE)
  LIST(FIND MueLu_PACKAGE_LIST Ifpack2 MueLu_Ifpack2_List_ID)
  LIST(FIND MueLu_PACKAGE_LIST Amesos2 MueLu_Amesos2_List_ID)
  IF (MueLu_Ifpack2_List_ID GREATER -1 AND MueLu_Amesos2_List_ID GREATER -1 AND ALBANY_AMESOS2_OPERATIONAL_SOLVER)
    MESSAGE("  -- MueLu tests enabled")
    SET(ALBANY_MUELU_EXAMPLES TRUE)
  ELSE()
    MESSAGE("  -- MueLu tests NOT enabled. Ifpack2 and Amesos2 compiled with an operational solver are required.")
    SET(ALBANY_MUELU_EXAMPLES FALSE)
  ENDIF()
ELSE()
  MESSAGE("-- Looking for MueLu ...                     NOT Found.")
  SET(ALBANY_MUELU FALSE)
  SET(ALBANY_MUELU_EXAMPLES FALSE)
ENDIF()

# set optional dependency on FROSch, for preconditioning
LIST(FIND Trilinos_PACKAGE_LIST ShyLU_DDFROSch FROSch_List_ID)
IF (FROSch_List_ID GREATER -1)
  MESSAGE("-- Looking for FROSch ...                        Found.")
  SET(ALBANY_FROSCH TRUE)
ELSE()
  MESSAGE("-- Looking for FROSch ...                    NOT Found.")
  SET(ALBANY_FROSCH FALSE)
ENDIF()

# Check if Trilinos has ROL
LIST(FIND Trilinos_PACKAGE_LIST ROL ROL_List_ID)
IF (ROL_List_ID GREATER -1)
  MESSAGE("-- Looking for ROL ...                           Found.")
  SET(ALBANY_ROL TRUE)
ELSE()
  MESSAGE("-- Looking for ROL ...                       NOT Found.")
  SET(ALBANY_ROL FALSE)
ENDIF()

# Check if Trilinos has DTK
LIST(FIND Trilinos_PACKAGE_LIST DataTransferKit DataTransferKit_List_ID)
IF (DataTransferKit_List_ID GREATER -1)
  MESSAGE("-- Looking for DTK ...                           Found.")
  SET(ALBANY_DTK TRUE)
ELSE()
  MESSAGE("-- Looking for DTK ...                       NOT Found.")
  SET(ALBANY_DTK FALSE)
ENDIF()

# Set optional dependency on SEACAS, for I/O via stk_io
LIST(FIND Trilinos_PACKAGE_LIST SEACASIoss SEACASIoss_List_ID)
IF (SEACASIoss_List_ID GREATER -1)
  MESSAGE("-- Looking for SEACASIoss ...                    Found.")
  SET(ALBANY_SEACAS TRUE)
  LIST(FIND SEACASIoss_LIBRARIES Iopx Iopx_List_ID)
  IF (Iopx_List_ID GREATER -1)
    MESSAGE("  -- Looking for Iopx ...                        Found.")
    SET(ALBANY_IOPX TRUE)
  ELSE()
    MESSAGE("  -- Looking for Iopx ...                    NOT Found.")
    SET(ALBANY_IOPX FALSE)
  ENDIF()
ELSE()
  MESSAGE("-- Looking for SEACASIoss ...                NOT Found.")
  SET(ALBANY_SEACAS FALSE)
ENDIF()

# Check whether Exodus can access a file in parallel
include(CheckCSourceCompiles)
set(CMAKE_REQUIRED_LIBRARIES ${${PROJECT_NAME}_EXTRA_LINK_FLAGS})
set(CMAKE_REQUIRED_INCLUDES  ${Trilinos_INCLUDE_DIRS} ${Trilinos_TPL_INCLUDE_DIRS})
check_c_source_compiles(
  "
  #include <exodusII_par.h>
  #if !NC_HAS_HDF5
  #error Missing hdf5
  #elif !NC_HAS_PNETCDF
  #error Missing pnetcdf
  #endif
  int main()
  {
    return 0;
  }
  "
  PARALLEL_EXODUS_SUPPORTED
  )

IF(NOT ENABLE_PARALLEL_EXODUS) 
  SET(PARALLEL_EXODUS_SUPPORTED FALSE)
  MESSAGE("-- User requested to turn off ALBANY_PARALELL_EXODUS")
ENDIF()


IF (PARALLEL_EXODUS_SUPPORTED)
  SET(ALBANY_PARALELL_EXODUS TRUE)
  MESSAGE("-- ALBANY_PARALELL_EXODUS set to True")
ELSE()
  SET(ALBANY_PARALELL_EXODUS FALSE)
  MESSAGE("-- ALBANY_PARALELL_EXODUS set to False")
ENDIF()


##########################################
### Check Albany configuration options ###
##########################################

MESSAGE ("\n  ************************************")
MESSAGE ("  *** Albany configuration options ***")
MESSAGE ("  ************************************\n")

IF (DEFINED CMAKE_BUILD_TYPE)
   IF ("${CMAKE_BUILD_TYPE}" STREQUAL "DEBUG")
      MESSAGE("-- CMAKE_BUILD_TYPE=DEBUG...  Debug build is Enabled")
      SET(ALBANY_DEBUG_BUILD ON)
   ELSE()
      MESSAGE("-- CMAKE_BUILD_TYPE=RELEASE...  Debug build is NOT Enabled")
      SET(ALBANY_DEBUG_BUILD OFF)
   ENDIF()
ENDIF()

IF (ENABLE_ALBANY_PYTHON)
  MESSAGE("-- ALBANY_PYTHON                           Enabled.")
  SET(ALBANY_PYTHON TRUE)
ELSE()
  MESSAGE("-- ALBANY_PYTHON                       NOT Enabled.")
  SET(ALBANY_PYTHON FALSE)
ENDIF()

# set optional dependency of mesh on solution, defaults to Disabled
OPTION(ENABLE_MESH_DEPENDS_ON_SOLUTION "Flag to turn on dependency of mesh on parameters, e.g for shape optimization" OFF)
IF (ENABLE_MESH_DEPENDS_ON_SOLUTION)
  MESSAGE("-- MESH_DEPENDS_ON_SOLUTION              Enabled.")
  SET(ALBANY_MESH_DEPENDS_ON_SOLUTION TRUE)
ELSE()
  MESSAGE("-- MESH_DEPENDS_ON_SOLUTION          NOT Enabled.")
  SET(ALBANY_MESH_DEPENDS_ON_SOLUTION FALSE)
ENDIF()

# set optional dependency of mesh on parameters, defaults to Disabled
OPTION(ENABLE_MESH_DEPENDS_ON_PARAMETERS "Flag to turn on dependency of mesh on parameters, e.g for shape optimization" ${ALBANY_MESH_DEPENDS_ON_SOLUTION})
IF (ENABLE_MESH_DEPENDS_ON_PARAMETERS)
  MESSAGE("-- MESH_DEPENDS_ON_PARAMETERS              Enabled.")
  SET(ALBANY_MESH_DEPENDS_ON_PARAMETERS TRUE)
ELSEIF(ALBANY_MESH_DEPENDS_ON_SOLUTION)
  MESSAGE(FATAL_ERROR
  "\nMESH_DEPENDS_ON_PARAMETERS cannot be OFF if MESH_DEPENDS_ON_SOLUTION is ON: ")
ELSE()
  MESSAGE("-- MESH_DEPENDS_ON_PARAMETERS          NOT Enabled.")
  SET(ALBANY_MESH_DEPENDS_ON_PARAMETERS FALSE)
ENDIF()

MESSAGE("\nAlbany physics packages:\n")

# set optional dependency on demoPDEs, defaults to Enabled
OPTION(ENABLE_DEMO_PDES "Flag to turn on demonstration PDEs problems" OFF)
IF (ENABLE_DEMO_PDES)
  MESSAGE("-- DEMO_PDES                               Enabled.")
ELSE()
  MESSAGE("-- DEMO_PDES                           NOT Enabled.")
ENDIF()

# Set optional build of LandIce (Land Ice SciDAC project), defaults to Disabled
OPTION(ENABLE_LANDICE "Flag to turn on LandIce Source code" OFF)
IF (ENABLE_LANDICE)
  MESSAGE("-- LandIce                                 Enabled.")
ELSE()
  MESSAGE("-- LandIce                             NOT Enabled.")
ENDIF()

## Other Albany Template Options here:
MESSAGE("\nAlbany Templated Data Type Options:\n")

# Set FAD data type
SET(ENABLE_FAD_TYPE "DFad" CACHE STRING "Sacado forward mode automatic differentiation data type")
IF(ENABLE_FAD_TYPE STREQUAL "SFad")
  SET(ALBANY_FAD_TYPE_SFAD TRUE)
  SET(ALBANY_SFAD_SIZE 32 CACHE STRING "Number of derivative components chosen at compile-time for AD")
  MESSAGE("-- FAD_TYPE  is SFad, ALBANY_SFAD_SIZE=${ALBANY_SFAD_SIZE}")
  MESSAGE("---> WARNING: problems with elemental DOFs > ${ALBANY_SFAD_SIZE} will fail")
ELSEIF(ENABLE_FAD_TYPE STREQUAL "SLFad")
  SET(ALBANY_FAD_TYPE_SLFAD TRUE)
  SET(ALBANY_SLFAD_SIZE 32 CACHE STRING "Maximum number of derivative components chosen at compile-time for AD")
  MESSAGE("-- FAD_TYPE  is SLFad, ALBANY_SLFAD_SIZE=${ALBANY_SLFAD_SIZE}")
  MESSAGE("---> WARNING: problems with elemental DOFs > ${ALBANY_SLFAD_SIZE} will fail")
ELSEIF(ENABLE_FAD_TYPE STREQUAL "DFad")
  MESSAGE("-- FAD_TYPE  is DFad (default)")
ELSE()
  MESSAGE(FATAL_ERROR
  "\nError: ENABLE_FAD_TYPE = ${ENABLE_FAD_TYPE} is not recognized!
  Options: SFad, SLFad, DFad (default)")
ENDIF()

# Set FAD data type for Tangent
SET(ENABLE_TAN_FAD_TYPE "DFad" CACHE STRING "Sacado forward mode automatic differentiation data type for Tangent")
IF(ENABLE_TAN_FAD_TYPE STREQUAL "SFad")
  SET(ALBANY_TAN_FAD_TYPE_SFAD TRUE)
  SET(ALBANY_TAN_SFAD_SIZE 32 CACHE STRING "Number of derivative components chosen at compile-time for Tangent AD")
  MESSAGE("-- TAN_FAD_TYPE is SFad, ALBANY_TAN_SFAD_SIZE=${ALBANY_TAN_SFAD_SIZE}")
  MESSAGE("---> WARNING: problems with Tangent elemental DOFs > ${ALBANY_TAN_SFAD_SIZE} will fail")
ELSEIF(ENABLE_TAN_FAD_TYPE STREQUAL "SLFad")
  SET(ALBANY_TAN_FAD_TYPE_SLFAD TRUE)
  SET(ALBANY_TAN_SLFAD_SIZE 32 CACHE STRING "Maximum number of derivative components chosen at compile-time for Tangent AD")
  MESSAGE("-- TAN_FAD_TYPE is SLFad, ALBANY_TAN_SLFAD_SIZE=${ALBANY_TAN_SLFAD_SIZE}")
  MESSAGE("---> WARNING: problems with Tangent elemental DOFs > ${ALBANY_TAN_SLFAD_SIZE} will fail")
ELSEIF(ENABLE_TAN_FAD_TYPE STREQUAL "DFad")
  MESSAGE("-- TAN_FAD_TYPE is DFad (default)")
ELSE()
  MESSAGE(FATAL_ERROR
  "\nError: ENABLE_TAN_FAD_TYPE = ${ENABLE_TAN_FAD_TYPE} is not recognized!
  Options: SFad, SLFad, DFad")
ENDIF()

# Set FAD data type for Hessian
SET(ENABLE_HES_VEC_FAD_TYPE "DFad" CACHE STRING "Sacado forward mode automatic differentiation data type for Hessian-vector product")
IF(ENABLE_HES_VEC_FAD_TYPE STREQUAL "SFad")
  SET(ALBANY_HES_VEC_FAD_TYPE_SFAD TRUE)
  SET(ALBANY_HES_VEC_SFAD_SIZE 32 CACHE STRING "Number of derivative components chosen at compile-time for Hessian-vector AD")
  MESSAGE("-- HES_VEC_FAD_TYPE is SFad, ALBANY_HES_VEC_SFAD_SIZE=${ALBANY_HES_VEC_SFAD_SIZE}")
  MESSAGE("---> WARNING: problems with elemental DOFs > ${ALBANY_HES_VEC_SFAD_SIZE} will fail")
ELSEIF(ENABLE_HES_VEC_FAD_TYPE STREQUAL "SLFad")
  SET(ALBANY_HES_VEC_FAD_TYPE_SLFAD TRUE)
  SET(ALBANY_HES_VEC_SLFAD_SIZE 32 CACHE STRING "Maximum number of derivative components chosen at compile-time for Hessian-vector AD")
  MESSAGE("-- HES_VEC_FAD_TYPE is SLFad, ALBANY_HES_VEC_SLFAD_SIZE=${ALBANY_HES_VEC_SLFAD_SIZE}")
  MESSAGE("---> WARNING: problems with elemental DOFs > ${ALBANY_HES_VEC_SLFAD_SIZE} will fail")
ELSEIF(ENABLE_HES_VEC_FAD_TYPE STREQUAL "DFad")
  MESSAGE("-- HES_VEC_FAD_TYPE is DFad (default)")
ELSE()
  MESSAGE(FATAL_ERROR
  "\nError: ENABLE_HES_VEC_FAD_TYPE = ${ENABLE_HES_VEC_FAD_TYPE} is not recognized!
  Options: SFad, SLFad, DFad")
ENDIF()

# Check if FAD data type is the same
IF(ENABLE_FAD_TYPE STREQUAL ENABLE_TAN_FAD_TYPE)
  IF(ALBANY_FAD_TYPE_SFAD AND NOT ALBANY_SFAD_SIZE EQUAL ALBANY_TAN_SFAD_SIZE)
    SET(ALBANY_FADTYPE_NOTEQUAL_TANFADTYPE TRUE)
    MESSAGE("-- SFAD_SIZE is not TAN_SFAD_SIZE")
  ELSEIF(ALBANY_FAD_TYPE_SLFAD AND NOT ALBANY_SLFAD_SIZE EQUAL ALBANY_TAN_SLFAD_SIZE)
    SET(ALBANY_FADTYPE_NOTEQUAL_TANFADTYPE TRUE)
    MESSAGE("-- SLFAD_SIZE is not TAN_SLFAD_SIZE")
  ENDIF()
ELSE()
  SET(ALBANY_FADTYPE_NOTEQUAL_TANFADTYPE TRUE)
  MESSAGE("-- FAD_TYPE is not TAN_FAD_TYPE")
ENDIF()

# Disable the RTC capability if Trilinos is not built with Pamgen
LIST(FIND Trilinos_PACKAGE_LIST Pamgen PAMGEN_List_ID)
  IF (NOT PAMGEN_List_ID GREATER -1)
    set(ALBANY_PAMGEN FALSE)
    MESSAGE("-- Pamgen package not found, disabling run time compiler support.")
  ELSE()
    set(ALBANY_PAMGEN TRUE)
    MESSAGE("-- Pamgen package found, enabling run time compiler support.")
  ENDIF()

## Other Miscellaneous Albany Options here:
MESSAGE("\nMiscellaneous Albany Options:\n")

# Optional CUDA settings
IF(Kokkos_ENABLE_CUDA)
  SET(KOKKOS_NDEVICES "--kokkos-map-device-id-by=mpi_rank")
ENDIF()

# Add option to check for hardware floating point exceptions using SSE, defaults to disabled
OPTION(ENABLE_CHECK_FPE "Flag to turn on floating point exception (NAN) checking" OFF)

# Add option to check for hardware floating point exceptions using SSE, defaults to disabled
OPTION(ENABLE_CHECK_FPE "Flag to turn on floating point exception (NAN) checking" OFF)
IF (ENABLE_CHECK_FPE)
  MESSAGE("-- FPE checking              Enabled")
  SET(ALBANY_CHECK_FPE TRUE)
ELSE()
  MESSAGE("-- FPE checking          NOT Enabled.")
  SET(ALBANY_CHECK_FPE FALSE)
ENDIF()

OPTION(ENABLE_STRONG_FPE_CHECK "Flag to turn on strong checking for floating point exceptions" OFF)
IF (ENABLE_STRONG_FPE_CHECK)
  MESSAGE("-- Strong FPE checking       Enabled")
  SET(ALBANY_STRONG_FPE_CHECK TRUE)
ELSE()
  MESSAGE("-- Strong FPE checking   NOT Enabled.")
  SET(ALBANY_STRONG_FPE_CHECK FALSE)
ENDIF()

# Add option to set FTZ and DAZ
OPTION(ENABLE_FLUSH_DENORMALS "Flag to turn on FTZ and DAZ" OFF)
IF (ENABLE_FLUSH_DENORMALS)
  MESSAGE("-- FTZ/DAZ flags             Enabled")
  SET(ALBANY_FLUSH_DENORMALS TRUE)
ELSE()
  MESSAGE("-- FTZ/DAZ flags         NOT Enabled.")
  SET(ALBANY_FLUSH_DENORMALS FALSE)
ENDIF()

OPTION(ENABLE_ALBANY_VERBOSE "Flag to turn on verbose output" OFF)
IF (ENABLE_ALBANY_VERBOSE)
  MESSAGE("-- Verbose printing          Enabled")
  SET(ALBANY_VERBOSE TRUE)
ELSE()
  MESSAGE("-- Verbose printing      NOT Enabled")
  SET(ALBANY_VERBOSE FALSE)
ENDIF()

# Enhanced debugging option
OPTION(ENABLE_DEBUGGING "Flag to turn on enhanced debugging info" OFF)
IF (ENABLE_DEBUGGING)
  MESSAGE("-- Enhanced debugging        Enabled")
  SET(ALBANY_DEBUG TRUE)
ELSE()
  MESSAGE("-- Enhanced debugging    NOT Enabled.")
  SET(ALBANY_DEBUG FALSE)
ENDIF()

# Set which memory analysis system routines are available.
option(ENABLE_MALLINFO "Use mallinfo() in Albany::printMemoryAnalysis()" OFF)
option(ENABLE_GETRUSAGE "Use getrusage() in Albany::printMemoryAnalysis()" OFF)
option(ENABLE_KERNELGETMEMORYSIZE "Use Kernel_GetMemorySize() in Albany::printMemoryAnalysis()" OFF)
if (ENABLE_MALLINFO)
  SET(ALBANY_HAVE_MALLINFO TRUE)
  message("-- Memory: mallinfo()        Enabled.")
endif()
if (ENABLE_GETRUSAGE)
  SET(ALBANY_HAVE_GETRUSAGE TRUE)
  message("-- Memory: getrusage()       Enabled.")
endif()
if (ENABLE_KERNELGETMEMORYSIZE)
  SET(ALBANY_HAVE_KERNELGETMEMORYSIZE ON)
  message("-- Memory: Kernel_GetMemorySize() Enabled.")
endif()

# Set MPI args
IF(ALBANY_MPI_EXEC)
  SET(MPIEX  ${ALBANY_MPI_EXEC})
ELSE()
  SET(MPIEX  ${Trilinos_MPI_EXEC})
ENDIF()
IF(ALBANY_MPI_EXEC_NUMPROCS_FLAG)
  SET(MPINPF  ${ALBANY_MPI_EXEC_NUMPROCS_FLAG})
ELSE()
  SET(MPINPF ${Trilinos_MPI_EXEC_NUMPROCS_FLAG})
ENDIF()
IF(ALBANY_MPI_EXEC_MAX_NUMPROCS)
  SET(MPIMNP ${ALBANY_MPI_EXEC_MAX_NUMPROCS})
ELSE()
  SET(MPIMNP ${Trilinos_MPI_EXEC_MAX_NUMPROCS})
ENDIF()
IF(ALBANY_MPI_EXEC_LEADING_OPTIONS)
  SET(MPIPRE ${ALBANY_MPI_EXEC_LEADING_OPTIONS})
  SEPARATE_ARGUMENTS(MPIPRE)
ENDIF()
IF(ALBANY_MPI_EXEC_TRAILING_OPTIONS)
  SET(MPIPOST ${ALBANY_MPI_EXEC_TRAILING_OPTIONS})
  SEPARATE_ARGUMENTS(MPIPOST)
ENDIF()

# Mesh database tools.
OPTION(ENABLE_MESHDB_TOOLS "Flag to turn on mesh database tools" OFF)
IF (ENABLE_MESHDB_TOOLS)
  MESSAGE("-- Mesh database tools       Enabled.")
  SET(ALBANY_MESHDB_TOOLS TRUE)
ENDIF()

# Omega_h
OPTION(ENABLE_OMEGAH "Flag to turn on the Omega_h mesh interface" OFF)
IF (ENABLE_OMEGAH)
  MESSAGE("-- Omega_h mesh interface    Enabled.")
  SET(ALBANY_OMEGAH TRUE)
  include (GetOrInstallOmegah)
else()
  MESSAGE("-- Omega_h lib interface NOT Enabled.")
ENDIF()

# add a target to generate API documentation with Doxygen
option (DISABLE_DOXYGEN "Whether to disable doxygen" ON)
IF( NOT DISABLE_DOXYGEN )
  find_package(Doxygen)
  if(DOXYGEN_FOUND)
    configure_file(${CMAKE_CURRENT_SOURCE_DIR}/doc/doxygen/Doxyfile.in ${CMAKE_CURRENT_BINARY_DIR}/Doxyfile @ONLY)
    configure_file(${CMAKE_CURRENT_SOURCE_DIR}/doc/doxygen/albanyMainPage.doc ${CMAKE_CURRENT_BINARY_DIR}/albanyMainPage.doc)
    add_custom_target(doc
      ${DOXYGEN_EXECUTABLE} ${CMAKE_CURRENT_BINARY_DIR}/Doxyfile
      WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
      COMMENT "Generating API documentation with Doxygen" VERBATIM
    )
  endif(DOXYGEN_FOUND)
ENDIF()

# Enables experimental features/tests. This may cause compilation errors and/or
# tests failures, as it includes code that is currently developed.

OPTION (ENABLE_EXPERIMENTAL "Enables experimental features/tests." OFF)

# Disable ability to write to output mesh. On slow filesystems, this can give faster
# execution time, if one is only interested in regression test against baseline
# response/sensitivity values.
option (ALBANY_DISABLE_OUTPUT_MESH "Disable writing of output mesh files" OFF)

########################## End of CMake options to Albany #########################################

# Parse source code folder
add_subdirectory(src)

#Add option to build libraries but not executables (for LandIce uner MPAS). Disables all tests
option(ALBANY_LIBRARIES_ONLY "Flag to only build libraries and not link executables" OFF)
#Add option to disable all tests
option(DISABLE_ALBANY_TESTS "Flag to disable tests" OFF)
if (ALBANY_LIBRARIES_ONLY)
  message("\nALBANY_LIBRARIES_ONLY has been set: turning off all tests.")
elseif (DISABLE_ALBANY_TESTS)
  message("\nDISABLE_ALBANY_TESTS has been set: turning off all tests.")
else()
  set(SERIAL_CALL ${MPIEX} ${MPIPRE} ${MPINPF} 1 ${MPIPOST})
  set(PARALLEL_CALL ${MPIEX} ${MPIPRE} ${MPINPF} ${MPIMNP} ${MPIPOST})
  string(REPLACE ";" " " SERIAL_CALL_TEXT "${SERIAL_CALL}")
  string(REPLACE ";" " " PARALLEL_CALL_TEXT "${PARALLEL_CALL}")

  # add albany test -- in the "tests" directory
  add_subdirectory(tests)
  message("-- CTest serial call: ${SERIAL_CALL_TEXT}")
  message("-- CTest parallel call: ${PARALLEL_CALL_TEXT}")
endif()

IF (ALBANY_PYTHON)
  IF (ALBANY_ROL)
    add_subdirectory( pyAlbany )
  ELSE()
    MESSAGE(FATAL_ERROR "PyAlbany requires a Trilinos installation that enables ROL.")
  ENDIF()
ENDIF()

# Make a clean build target for convenience

ADD_CUSTOM_TARGET( cmake_clean
    COMMAND ${CMAKE_COMMAND} -E remove ${CMAKE_CURRENT_BINARY_DIR}/CMakeCache.txt
    COMMAND ${CMAKE_COMMAND} -E remove ${CMAKE_CURRENT_BINARY_DIR}/Makefile
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles
    COMMAND ${CMAKE_COMMAND} -E remove ${CMAKE_CURRENT_BINARY_DIR}/cmake_install.cmake
    COMMAND ${CMAKE_COMMAND} -E remove ${CMAKE_CURRENT_BINARY_DIR}/CTestTestfile.cmake
)

MESSAGE("\nAnd CMake says...:")
