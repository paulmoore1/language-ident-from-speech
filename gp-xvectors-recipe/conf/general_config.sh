#!/bin/bash

# This config contains options that can be set automatically depending on the
# identified context (i.e. machine, for example Sam's DICE or a cluster node).
num_threads_per_core=$(lscpu | grep -oP '^Thread.*\K([0-9]+)')
num_cores_per_CPU=$(lscpu | grep -oP '^Core.*\K([0-9]+)')
num_CPUs=$(nproc)
MAXNUMJOBS=$(($num_CPUs*${num_cores_per_CPU}*$num_threads_per_core))
