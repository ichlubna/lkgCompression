set -x
#!/bin/bash
# Parameters: input views, otput folder with quilt, output folder with simulated images

QUILT_TO_NATIVE=/home/ichlubna/Workspace/quiltToNative/build/
QUILT_KERNEL=/home/ichlubna/Workspace/lkgCompression/QuiltToNativeDisplaySimulatorKernel.cl
INPUT=$(realpath $1) 
OUTPUT=$(realpath $2)
VIEW_COUNT=$(ls -1q $INPUT/* | wc -l)
cd $QUILT_TO_NATIVE
cp $QUILT_KERNEL ./kernel.cl
./QuiltToNative -i $INPUT -o $OUTPUT -cols $VIEW_COUNT -rows 1 -width 19200 -height 2560
cd -
blender -b ./displaySimulator.blend -P ./displaySimulation.py -- $2/output.png $3/
