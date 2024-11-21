#!/bin/bash
DATASET=$(realpath $1)
    
for CRF in 0 9 18 27 36 45 54 ../full; do
    echo $CRF
    cd /home/ichlubna/Workspace/quiltToNative/build/
    ./QuiltToNative -i $DATASET/$CRF -o ./result -cols 8 -rows 6 -width 1536 -height 2048 -pitch 246.867 -tilt -0.185828 -center 0.350117 -viewPortion 1 -subp 0.000217014 -focus 0
    cd -
    read -p "Waiting..."
    ./cameraControl.sh wake
    sleep 1
    ./cameraControl.sh shoot
    read -p "Waiting..."
done
