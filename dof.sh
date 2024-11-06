set -x
NATIVE=/home/ichlubna/Workspace/quiltToNative/build/
DOF=/home/ichlubna/Workspace/DoFFromDepthMap/build/
DOF_FOCUS_DISTANCE=0.63
DOF_FOCUS_BOUNDS=0.0
DOF_STRENGTH=50

#Parameters: input image, depth map, output image
function fakeDoF ()
{
    DOF_IN=$(realpath $1)
    DOF_DEPTH=$(realpath $2)
    DOF_OUT=$(realpath $3)
    cd $DOF  
    ./DoFFromDepthMap -i $DOF_IN -d $DOF_DEPTH -o $DOF_OUT -f $DOF_FOCUS_DISTANCE -b $DOF_FOCUS_BOUNDS -s $DOF_STRENGTH
    cd -
}

INPUT_IMAGE=$1/renders
INPUT_DEPTH=$1/depth
FULL_DOF=./fullDoF
mkdir -p $FULL_DOF
for FILE in $INPUT_IMAGE/*; do
	FILENAME=$(basename $FILE)
    FILENAME_NO_EXT="${FILENAME%.*}"
	fakeDoF $INPUT_IMAGE/$FILENAME $INPUT_DEPTH/$FILENAME_NO_EXT.hdr $FULL_DOF/$FILENAME
done

THIS_PATH=$(pwd)
THIS_PATH=$(realpath $THIS_PATH)
FULL_PATH=$(realpath $FULL_DOF)
cd $NATIVE
./QuiltToNative -i $FULL_PATH -o $THIS_PATH/result -cols 5 -rows 9 -width 2560 -height 1600 -pitch 354.677 -tilt -0.113949 -center -0.400272 -viewPortion 1 -subp 0.00013 -focus 0
