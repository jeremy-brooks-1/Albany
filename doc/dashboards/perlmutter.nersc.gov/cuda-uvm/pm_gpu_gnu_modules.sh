#!/bin/bash

module load PrgEnv-gnu/8.5.0
module load gcc-native/12.3
module load cudatoolkit/12.4
module load craype-accel-nvidia80
module load cray-libsci/23.12.5
module load craype/2.7.30
module load cray-mpich/8.1.28
module load cray-hdf5-parallel/1.12.2.9
module load cray-netcdf-hdf5parallel/4.9.0.9
module load cray-parallel-netcdf/1.12.3.9
module load cmake/3.24.3

# The SuperLU e4s install on Perlmutter-GPU is currently causing issues, if you need SuperLU,
#  you will have to build it manually for now.
#module load e4s/23.08
#spack env activate -V gcc
#spack load superlu

export MPICH_ENV_DISPLAY=1
export MPICH_VERSION_DISPLAY=1
export OMP_STACKSIZE=128M
export OMP_PROC_BIND=spread
export OMP_PLACES=threads
export HDF5_USE_FILE_LOCKING=FALSE
export MPICH_GPU_SUPPORT_ENABLED=1
export CUDATOOLKIT_VERSION_STRING=${CRAY_CUDATOOLKIT_VERSION#*_}

export KOKKOS_MAP_DEVICE_ID_BY=mpi_rank
export CUDA_MANAGED_FORCE_DEVICE_ALLOC=1
export TPETRA_ASSUME_GPU_AWARE_MPI=0

# To enable GPU-aware MPI, use the following two environment variables instead
#export TPETRA_ASSUME_GPU_AWARE_MPI=1
#export FI_HMEM_CUDA_USE_GDRCOPY=0