#!/bin/bash

# This config contains options that can be set automatically depending on the
# identified context (i.e. machine, for example Sam's DICE or a cluster node).

MAXNUMJOBS=$(grep -c ^processor /proc/cpuinfo)
