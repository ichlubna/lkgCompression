set -x
set -e
#!/bin/bash
INPUT_PATH=$(realpath $1)
QUALITY=$2
FOCUS=$3

FFMPEG=ffmpeg
MAGICK=magick
VVCENC=./vvenc/bin/release-static/vvencapp
VVCDEC=./vvdec/bin/release-static/vvdecapp
# https://github.com/ichlubna/DoFFromDepthMap 
DOF=/home/ichlubna/Workspace/DoFFromDepthMap/build/
# https://github.com/ichlubna/quiltToNative 
QUILT_TO_NATIVE=/home/ichlubna/Workspace/quiltToNative/build/
# https://github.com/LiheYoung/Depth-Anything
DEPTH_ANYTHING=/home/ichlubna/Workspace/Depth-Anything
TEMP=$(mktemp -d)
DOF_STRENGTH=20
FULL_MEASURE=1
ENCODER_OPTIONS="-rs 2 -c yuv420 --preset medium --qpa 1"

#Parameters: input, output
function compress ()
{
	$FFMPEG -y -i $1 -pix_fmt yuv420p $TEMP/temp.y4m
	$VVCENC -i $TEMP/temp.y4m $ENCODER_OPTIONS -q $QUALITY -o $2
}

function decompress ()
{
	#$VVCDEC -b $1 --y4m -o $TEMP/temp.y4m
	#$FFMPEG -y -i $TEMP/temp.y4m $2
	$FFMPEG -y -strict -2 -i $1 $2
}

# Generating depth maps from input images
INPUT_PATH_DEPTH=$TEMP/inputDepth
mkdir $INPUT_PATH_DEPTH
INPUT_PNG=$TEMP/pngs
mkdir $INPUT_PNG
cd $DEPTH_ANYTHING
#$FFMPEG -i $INPUT_PATH/%04d.png -pix_fmt rgba $INPUT_PNG/%04d.png
#python run.py --encoder vitl --img-path $INPUT_PNG --outdir $INPUT_PATH_DEPTH --grayscale --pred-only
cd -

# Applying dof to the input images
INPUT_PATH_DOF=$TEMP/inputDof
mkdir $INPUT_PATH_DOF
INPUT_PATH_DOF_HALF=$TEMP/inputDofHalf
mkdir $INPUT_PATH_DOF_HALF
cd $DOF  
#for FILE in $INPUT_PATH/*.png; do
#	FILENAME=$(basename $FILE)
#    FILENAME_NO_EXT="${FILENAME%.*}"
#    ./DoFFromDepthMap -i $INPUT_PATH/$FILENAME -d $INPUT_PATH_DEPTH/$FILENAME_NO_EXT.hdr -o $INPUT_PATH_DOF/$FILENAME -f $FOCUS -b 0.1 -s $DOF_STRENGTH
#    ./DoFFromDepthMap -i $INPUT_PATH_DOF/$FILENAME -d $INPUT_PATH_DEPTH/$FILENAME_NO_EXT.hdr -o $INPUT_PATH_DOF/$FILENAME -f $FOCUS -b 0.1 -s $DOF_STRENGTH
#    ./DoFFromDepthMap -i $INPUT_PATH/$FILENAME -d $INPUT_PATH_DEPTH/$FILENAME_NO_EXT.hdr -o $INPUT_PATH_DOF_HALF/$FILENAME -f $FOCUS -b 0.1 -s $DOF_STRENGTH
#done
cd -

compress $INPUT_PATH/%04d.png $TEMP/compressed.mkv
#compress $INPUT_PATH_DOF/%04d.png $TEMP/compressedDof.mkv
#compress $INPUT_PATH_DOF_HALF/%04d.png $TEMP/compressedDofHalf.mkv

DECOMPRESSED_PATH=$TEMP/decompressed
mkdir $DECOMPRESSED_PATH
DECOMPRESSED_PATH_DOF=$TEMP/decompressedDof
mkdir $DECOMPRESSED_PATH_DOF
DECOMPRESSED_PATH_DOF_HALF=$TEMP/decompressedDofHalf
mkdir $DECOMPRESSED_PATH_DOF_HALF
decompress $TEMP/compressed.mkv $DECOMPRESSED_PATH/%04d.png
#decompress $TEMP/compressedDof.mkv $DECOMPRESSED_PATH_DOF/%04d.png
#decompress $TEMP/compressedDofHalf.mkv $DECOMPRESSED_PATH_DOF_HALF/%04d.png

# Applying second half of dof and full dof to undoffed and to reference
DECOMPRESSED_PATH_DOF_HALF_FINISHED=$TEMP/decompressedDofHalfFinished
mkdir $DECOMPRESSED_PATH_DOF_HALF_FINISHED
DECOMPRESSED_PATH_DOF_POST=$TEMP/decompressedDofPost
mkdir $DECOMPRESSED_PATH_DOF_POST
DOF_REFERENCE=$TEMP/reference
mkdir $DOF_REFERENCE
cd $DOF  
#for FILE in $INPUT_PATH/*.png; do
#	FILENAME=$(basename $FILE)
#    FILENAME_NO_EXT="${FILENAME%.*}"
#    ./DoFFromDepthMap -i $DECOMPRESSED_PATH/$FILENAME -d $INPUT_PATH_DEPTH/$FILENAME_NO_EXT.hdr -o $DECOMPRESSED_PATH_DOF_POST/$FILENAME -f $FOCUS -b 0.1 -s $DOF_STRENGTH
#    ./DoFFromDepthMap -i $DECOMPRESSED_PATH_DOF/$FILENAME -d $INPUT_PATH_DEPTH/$FILENAME_NO_EXT.hdr -o $DECOMPRESSED_PATH_DOF_POST/$FILENAME -f $FOCUS -b 0.1 -s $DOF_STRENGTH
#    ./DoFFromDepthMap -i $DECOMPRESSED_PATH_DOF_HALF/$FILENAME -d $INPUT_PATH_DEPTH/$FILENAME_NO_EXT.hdr -o $DECOMPRESSED_PATH_DOF_HALF_FINISHED/$FILENAME -f $FOCUS -b 0.1 -s $DOF_STRENGTH
#    ./DoFFromDepthMap -i $INPUT_PATH/$FILENAME -d $INPUT_PATH_DEPTH/$FILENAME_NO_EXT.hdr -o $DOF_REFERENCE/$FILENAME -f $FOCUS -b 0.1 -s $DOF_STRENGTH
#    ./DoFFromDepthMap -i $DOF_REFERENCE/$FILENAME -d $INPUT_PATH_DEPTH/$FILENAME_NO_EXT.hdr -o $DOF_REFERENCE/$FILENAME -f $FOCUS -b 0.1 -s $DOF_STRENGTH
#done
cd -

DOF_PRE=$DECOMPRESSED_PATH_DOF
DOF_POST=$DECOMPRESSED_PATH_DOF_POST
DOF_HALF=$DECOMPRESSED_PATH_DOF_HALF_FINISHED

# Blended metric
BLENDED_DOF_REFERENCE=$TEMP/blendedDofRef
mkdir $BLENDED_DOF_REFERENCE
BLENDED_DOF_PRE=$TEMP/blendedDofPre
mkdir $BLENDED_DOF_PRE
BLENDED_DOF_POST=$TEMP/blendedDofPost
mkdir $BLENDED_DOF_POST
BLENDED_DOF_HALF=$TEMP/blendedDofHalf
mkdir $BLENDED_DOF_HALF
BLENDED_NODOF_REF=$TEMP/blendedNodofRef
mkdir $BLENDED_NODOF_REF
BLENDED_NODOF_DEC=$TEMP/blendedNodofDec
mkdir $BLENDED_NODOF_DEC
#./blendViews.sh $DOF_REFERENCE $BLENDED_DOF_REFERENCE
#./blendViews.sh $DOF_PRE $BLENDED_DOF_PRE
#./blendViews.sh $DOF_POST $BLENDED_DOF_POST
#./blendViews.sh $DOF_HALF $BLENDED_DOF_HALF
#./blendViews.sh $INPUT_PATH $BLENDED_NODOF_REF
#./blendViews.sh $DECOMPRESSED_PATH $BLENDED_NODOF_DEC

# All blended metric
NAMES=$(find $DOF_REFERENCE -maxdepth 1 | tail -n +2 | tr '\n' ' ')
ALL_BLEND_DOF_REF=$TEMP/allBlendDofRef.png
#$MAGICK $NAMES -evaluate-sequence Mean $ALL_BLEND_DOF_REF
NAMES=$(find $DOF_PRE -maxdepth 1 | tail -n +2 | tr '\n' ' ')
ALL_BLEND_DOF_PRE=$TEMP/allBlendDofPre.png
#$MAGICK $NAMES -evaluate-sequence Mean $ALL_BLEND_DOF_PRE
NAMES=$(find $DOF_POST -maxdepth 1 | tail -n +2 | tr '\n' ' ')
ALL_BLEND_DOF_POST=$TEMP/allBlendDofPost.png
#$MAGICK $NAMES -evaluate-sequence Mean $ALL_BLEND_DOF_POST
NAMES=$(find $DOF_HALF -maxdepth 1 | tail -n +2 | tr '\n' ' ')
ALL_BLEND_DOF_HALF=$TEMP/allBlendDofHalf.png
#$MAGICK $NAMES -evaluate-sequence Mean $ALL_BLEND_DOF_HALF
NAMES=$(find $INPUT_PATH -maxdepth 1 | tail -n +2 | tr '\n' ' ')
ALL_BLEND_NODOF_REF=$TEMP/allBlendNoDofRef.png
$MAGICK $NAMES -evaluate-sequence Mean $ALL_BLEND_NODOF_REF
NAMES=$(find $DECOMPRESSED_PATH -maxdepth 1 | tail -n +2 | tr '\n' ' ')
ALL_BLEND_NODOF_DEC=$TEMP/allBlendNoDofDec.png
$MAGICK $NAMES -evaluate-sequence Mean $ALL_BLEND_NODOF_DEC
#QUALITY_ALL_BLENDED_PRE=$(./measureQuality.sh $ALL_BLEND_DOF_PRE $ALL_BLEND_DOF_REF $FULL_MEASURE)
#QUALITY_ALL_BLENDED_POST=$(./measureQuality.sh $ALL_BLEND_DOF_POST $ALL_BLEND_DOF_REF $FULL_MEASURE)
#QUALITY_ALL_BLENDED_HALF=$(./measureQuality.sh $ALL_BLEND_DOF_HALF $ALL_BLEND_DOF_REF $FULL_MEASURE)
QUALITY_ALL_BLENDED_DEC=$(./measureQuality.sh $ALL_BLEND_NODOF_DEC $ALL_BLEND_NODOF_REF $FULL_MEASURE)

# Native metric
mkdir $TEMP/native
cd $QUILT_TO_NATIVE
#./QuiltToNative -i $DOF_PRE -o $TEMP/native -cols 8 -rows 6 -width 1536 -height 2048 -pitch 246.867 -tilt -0.185828 -center 0.350117 -viewPortion 1 -subp 0.000217014 -focus 0
#mv $TEMP/native/output.png $TEMP/nativePre.png
#./QuiltToNative -i $DOF_POST -o $TEMP/native -cols 8 -rows 6 -width 1536 -height 2048 -pitch 246.867 -tilt -0.185828 -center 0.350117 -viewPortion 1 -subp 0.000217014 -focus 0
#mv $TEMP/native/output.png $TEMP/nativePost.png
#./QuiltToNative -i $DOF_HALF -o $TEMP/native -cols 8 -rows 6 -width 1536 -height 2048 -pitch 246.867 -tilt -0.185828 -center 0.350117 -viewPortion 1 -subp 0.000217014 -focus 0
#mv $TEMP/native/output.png $TEMP/nativeHalf.png
#./QuiltToNative -i $DOF_REFERENCE -o $TEMP/native -cols 8 -rows 6 -width 1536 -height 2048 -pitch 246.867 -tilt -0.185828 -center 0.350117 -viewPortion 1 -subp 0.000217014 -focus 0
#mv $TEMP/native/output.png $TEMP/nativeRef.png
./QuiltToNative -i $INPUT_PATH -o $TEMP/native -cols 8 -rows 6 -width 1536 -height 2048 -pitch 246.867 -tilt -0.185828 -center 0.350117 -viewPortion 1 -subp 0.000217014 -focus 0
mv $TEMP/native/output.png $TEMP/nativeNodofRef.png
./QuiltToNative -i $DECOMPRESSED_PATH -o $TEMP/native -cols 8 -rows 6 -width 1536 -height 2048 -pitch 246.867 -tilt -0.185828 -center 0.350117 -viewPortion 1 -subp 0.000217014 -focus 0
mv $TEMP/native/output.png $TEMP/nativeNodofDec.png
cd -
#QUALITY_NATIVE_PRE=$(./measureQuality.sh  $TEMP/nativePre.png $TEMP/nativeRef.png $FULL_MEASURE)
#QUALITY_NATIVE_POST=$(./measureQuality.sh  $TEMP/nativePost.png $TEMP/nativeRef.png $FULL_MEASURE)
#QUALITY_NATIVE_HALF=$(./measureQuality.sh  $TEMP/nativeHalf.png $TEMP/nativeRef.png $FULL_MEASURE)
QUALITY_NATIVE_DEC=$(./measureQuality.sh  $TEMP/nativeNodofDec.png $TEMP/nativeNodofRef.png $FULL_MEASURE)

# Simulated metric
mkdir $TEMP/simulatedPre
mkdir $TEMP/simulatedPost
mkdir $TEMP/simulatedHalf
mkdir $TEMP/simulatedRef
mkdir $TEMP/simulatedNodofRef
mkdir $TEMP/simulatedNodofDec
mkdir $TEMP/quiltForSim
#./simulateViews.sh $DOF_PRE $TEMP/quiltForSim $TEMP/simulatedPre 
#./simulateViews.sh $DOF_POST $TEMP/quiltForSim $TEMP/simulatedPost 
#./simulateViews.sh $DOF_HALF $TEMP/quiltForSim $TEMP/simulatedHalf 
#./simulateViews.sh $DOF_REFERENCE $TEMP/quiltForSim $TEMP/simulatedRef
./simulateViews.sh $INPUT_PATH $TEMP/quiltForSim $TEMP/simulatedNodofRef
./simulateViews.sh $DECOMPRESSED_PATH $TEMP/quiltForSim $TEMP/simulatedNodofDec
#QUALITY_SIMULATED_PRE=$(./measureQuality.sh  $TEMP/simulatedPre/ $TEMP/simulatedRef/ $FULL_MEASURE)
#QUALITY_SIMULATED_POST=$(./measureQuality.sh  $TEMP/simulatedPost/ $TEMP/simulatedRef/ $FULL_MEASURE)
#QUALITY_SIMULATED_HALF=$(./measureQuality.sh  $TEMP/simulatedHalf/ $TEMP/simulatedRef/ $FULL_MEASURE)
QUALITY_SIMULATED_DEC=$(./measureQuality.sh  $TEMP/simulatedNodofDec/ $TEMP/simulatedNodofRef/ $FULL_MEASURE)

# Simple decoding metric
#QUALITY_DECODED_PRE=$(./measureQuality.sh $DOF_PRE $DOF_REFERENCE $FULL_MEASURE)
#QUALITY_DECODED_POST=$(./measureQuality.sh $DOF_POST $DOF_REFERENCE $FULL_MEASURE)
#QUALITY_DECODED_HALF=$(./measureQuality.sh $DOF_HALF $DOF_REFERENCE $FULL_MEASURE)
#QUALITY_DECODED_DEC=$(./measureQuality.sh $DECOMPRESSED_PATH $INPUT_PATH $FULL_MEASURE)

echo "Results"
echo "No dof"
echo -n "Size:"
PRE_SIZE=$(stat --printf="%s" $TEMP/compressedDof.mkv)
echo $PRE_SIZE
#echo -n "Decoded:"
#echo $QUALITY_DECODED
#echo -n "Blended partially:"
#echo $QUALITY_BLENDED_DEC
echo -n "Blended all:"
echo $QUALITY_ALL_BLENDED_DEC
echo -n "Native:"
echo $QUALITY_NATIVE_DEC
echo -n "Simulated:"
echo $QUALITY_SIMULATED_DEC

echo "Pre"
echo -n "Size:"
#PRE_SIZE=$(stat --printf="%s" $TEMP/compressedDof.mkv)
#echo $PRE_SIZE
#echo -n "Decoded:"
#echo $QUALITY_DECODED_PRE
#echo -n "Blended partially:"
#echo $QUALITY_BLENDED_PRE
#echo -n "Blended all:"
#echo $QUALITY_ALL_BLENDED_PRE
#echo -n "Native:"
#echo $QUALITY_NATIVE_PRE
#echo -n "Simulated:"
#echo $QUALITY_SIMULATED_PRE

echo "Post"
echo -n "Size:"
#POST_SIZE=$(stat --printf="%s" $TEMP/compressed.mkv)
#echo $POST_SIZE
#echo -n "Decoded:"
#echo $QUALITY_DECODED_POST
#echo -n "Blended partially:"
#echo $QUALITY_BLENDED_POST
#echo -n "Blended all:"
#echo $QUALITY_ALL_BLENDED_POST
#echo -n "Native:"
#echo $QUALITY_NATIVE_POST
#echo -n "Simulated:"
#echo $QUALITY_SIMULATED_POST

echo "Half"
echo -n "Size:"
#HALF_SIZE=$(stat --printf="%s" $TEMP/compressedDofHalf.mkv)
#echo $HALF_SIZE
#echo -n "Decoded:"
#echo $QUALITY_DECODED_HALF
#echo -n "Blended partially:"
#echo $QUALITY_BLENDED_HALF
#echo -n "Blended all:"
#echo $QUALITY_ALL_BLENDED_HALF
#echo -n "Native:"
#echo $QUALITY_NATIVE_HALF
#echo -n "Simulated:"
#echo $QUALITY_SIMULATED_HALF

rm -rf $TEMP
