#!/bin/sh
num_frames=0
num_frames=`python calculate_frames.py --num-train-frames 1000000000 --num-repeats 35`
echo $num_frames
