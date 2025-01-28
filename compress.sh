#!/bin/bash
#set -x
#set -e
INPUT_PATH=$(realpath $1)
QUALITY=$2
THRESHOLD=$3
OUTPUT_PATH=$(realpath $4)

# https://github.com/FFmpeg/FFmpeg
FFMPEG=ffmpeg
# https://github.com/ImageMagick/ImageMagick
MAGICK=magick
# https://github.com/fraunhoferhhi/vvenc
VVCENC=./vvenc/bin/release-static/vvencapp
# https://github.com/fraunhoferhhi/vvdec
VVCDEC=./vvdec/bin/release-static/vvdecapp
# https://github.com/ichlubna/jpeg/tree/aitiv-dev
JPG=/home/ichlubna/Workspace/jpeg
# https://github.com/ichlubna/DoFFromDepthMap 
DOF=/home/ichlubna/Workspace/DoFFromDepthMap/build/
# https://github.com/ichlubna/quiltToNative 
QUILT_TO_NATIVE=/home/ichlubna/Workspace/quiltToNative/build/
# https://github.com/LiheYoung/Depth-Anything
DEPTH_ANYTHING=/home/ichlubna/Workspace/Depth-Anything
# https://github.com/ichlubna/quiltFocus
QUILT_FOCUS=/home/ichlubna/Workspace/quiltFocus/
TEMP=$(mktemp -d)
DOF_STRENGTH=20
FULL_MEASURE=0
ENCODER_OPTIONS="-rs 2 -c yuv420 --preset medium --qpa 1"
VIEW_COUNT=$(ls -1q $INPUT_PATH/* | wc -l)

#Parameters: input, output
function compress ()
{
	$FFMPEG -y -i $1 -pix_fmt yuv420p $TEMP/temp.y4m
	$VVCENC -i $TEMP/temp.y4m $ENCODER_OPTIONS -q $QUALITY -o $2
}

function compressLossless ()
{
	$FFMPEG -y -i $1 -pix_fmt yuv420p $TEMP/temp.y4m
	$VVCENC -i $TEMP/temp.y4m $ENCODER_OPTIONS -q 10 -o $2
}

function decompress ()
{
	#$VVCDEC -b $1 --y4m -o $TEMP/temp.y4m
	#$FFMPEG -y -i $TEMP/temp.y4m $2
	$FFMPEG -y -strict -2 -i $1 $2
}

# Generating depth maps from input images
INPUT_DEPTH=$TEMP/inputDepth
mkdir $INPUT_DEPTH
INPUT_DEPTH_PNG=$TEMP/inputDepthPng
mkdir $INPUT_DEPTH_PNG
INPUT_PNG=$TEMP/pngs
mkdir $INPUT_PNG
cd $DEPTH_ANYTHING
$FFMPEG -i $INPUT_PATH/%04d.png -pix_fmt rgba $INPUT_PNG/%04d.png
python run.py --encoder vitl --img-path $INPUT_PNG --outdir $INPUT_DEPTH_PNG --grayscale --pred-only
$FFMPEG -i $INPUT_DEPTH_PNG/%04d_depth.png $INPUT_DEPTH/%04d_depth.hdr
cd -

# Estimating optimal focus
cd $QUILT_FOCUS
FOCUS_INFO=$(./generateMap.sh $INPUT_PATH/%04d.png $INPUT_DEPTH_PNG/%04d_depth.png $TEMP/test.hdr)
echo $FOCUS_INFO
FOCUS_COORDS=$(echo "$FOCUS_INFO" | tail -1 | head -1)
DEPTH_8BIT=$(echo "$FOCUS_INFO" | tail -3 | head -1)
DEPTH=$(bc <<< "scale=5; $DEPTH_8BIT/255") 
DEPTH_NORM=$(echo "$FOCUS_INFO" | tail -2 | head -1)
cd -
cp -f $TEMP/test.hdr $OUTPUT_PATH/focusMap.hdr

# Applying dof to the input images
INPUT_PATH_DOF=$TEMP/inputDof
mkdir $INPUT_PATH_DOF
INPUT_PATH_DOF_HALF=$TEMP/inputDofHalf
mkdir $INPUT_PATH_DOF_HALF
cd $DOF  
for FILE in $INPUT_PATH/*.png; do
	FILENAME=$(basename $FILE)
    FILENAME_NO_EXT="${FILENAME%.*}"
    DEPTHNAME=$INPUT_DEPTH/$FILENAME_NO_EXT"_depth.hdr"
    ./DoFFromDepthMap -i $INPUT_PATH/$FILENAME -d $DEPTHNAME -o $INPUT_PATH_DOF/$FILENAME -f $DEPTH -b 0.1 -s $DOF_STRENGTH
    ./DoFFromDepthMap -i $INPUT_PATH_DOF/$FILENAME -d $DEPTHNAME -o $INPUT_PATH_DOF/$FILENAME -f $DEPTH -b 0.1 -s $DOF_STRENGTH
    ./DoFFromDepthMap -i $INPUT_PATH/$FILENAME -d $DEPTHNAME -o $INPUT_PATH_DOF_HALF/$FILENAME -f $DEPTH -b 0.1 -s $DOF_STRENGTH
done
cd -

compress $INPUT_PATH/%04d.png $TEMP/compressed.mkv
compress $INPUT_PATH_DOF/%04d.png $TEMP/compressedDof.mkv
compress $INPUT_PATH_DOF_HALF/%04d.png $TEMP/compressedDofHalf.mkv

# Compressing withot dof
PPM_INPUT=$TEMP/ppm
mkdir $PPM_INPUT
$FFMPEG -i $INPUT_PATH/%04d.png -pix_fmt rgb24 $PPM_INPUT/%04d.ppm
JPG_FULL_COMP=$TEMP/jpgFull
mkdir $JPG_FULL_COMP
JPG_ADAPTIVE=$TEMP/jpgAdaptive
mkdir $JPG_ADAPTIVE
JPG_REF=$TEMP/jpgReference
mkdir $JPG_REF
cd $JPG
for FILE in $PPM_INPUT/*.ppm; do
	FILENAME=$(basename $FILE)
    FILENAME_NO_EXT="${FILENAME%.*}"
    $MAGICK $INPUT_DEPTH_PNG/$FILENAME_NO_EXT"_depth.png" -compress none $TEMP/depth.pgm
    ./encoder -q 100 -o 1 -T $THRESHOLD -d $DEPTH_8BIT $FILE $JPG_ADAPTIVE/$FILENAME_NO_EXT.jpg $TEMP/depth.pgm
    ./encoder -q 100 -o 1 -T $THRESHOLD -r 9999,9999,99999,99999 $FILE $JPG_FULL_COMP/$FILENAME_NO_EXT.jpg 
    ./encoder -q 100 -o 1 -T 0 -r 9999,9999,99999,99999 $FILE $JPG_REF/$FILENAME_NO_EXT.jpg 
done
cd -

compressLossless $JPG_ADAPTIVE/%04d.jpg $TEMP/compressedJpgAdaptive.mkv
compressLossless $JPG_FULL_COMP/%04d.jpg $TEMP/compressedJpgFull.mkv
compressLossless $JPG_REF/%04d.jpg $TEMP/compressedJpgRef.mkv

DECOMPRESSED_PATH=$TEMP/decompressed
mkdir $DECOMPRESSED_PATH
DECOMPRESSED_PATH_DOF=$TEMP/decompressedDof
mkdir $DECOMPRESSED_PATH_DOF
DECOMPRESSED_PATH_DOF_HALF=$TEMP/decompressedDofHalf
mkdir $DECOMPRESSED_PATH_DOF_HALF
DECOMPRESSED_PATH_JPG_ADA=$TEMP/decompressedJpgAda
mkdir $DECOMPRESSED_PATH_JPG_ADA
DECOMPRESSED_PATH_JPG_FULL=$TEMP/decompressedJpgFull
mkdir $DECOMPRESSED_PATH_JPG_FULL
DECOMPRESSED_PATH_JPG_REF=$TEMP/decompressedJpgRef
mkdir $DECOMPRESSED_PATH_JPG_REF
decompress $TEMP/compressed.mkv $DECOMPRESSED_PATH/%04d.png
decompress $TEMP/compressedDof.mkv $DECOMPRESSED_PATH_DOF/%04d.png
decompress $TEMP/compressedDofHalf.mkv $DECOMPRESSED_PATH_DOF_HALF/%04d.png
decompress $TEMP/compressedJpgAdaptive.mkv $DECOMPRESSED_PATH_JPG_ADA/%04d.png
decompress $TEMP/compressedJpgFull.mkv $DECOMPRESSED_PATH_JPG_FULL/%04d.png
decompress $TEMP/compressedJpgRef.mkv $DECOMPRESSED_PATH_JPG_REF/%04d.png

# Applying second half of dof and full dof to undoffed and to reference
DECOMPRESSED_PATH_DOF_HALF_FINISHED=$TEMP/decompressedDofHalfFinished
mkdir $DECOMPRESSED_PATH_DOF_HALF_FINISHED
DECOMPRESSED_PATH_DOF_POST=$TEMP/decompressedDofPost
mkdir $DECOMPRESSED_PATH_DOF_POST
DOF_REFERENCE=$TEMP/reference
mkdir $DOF_REFERENCE
cd $DOF  
for FILE in $INPUT_PATH/*.png; do
	FILENAME=$(basename $FILE)
    FILENAME_NO_EXT="${FILENAME%.*}"
    DEPTHNAME=$INPUT_DEPTH/$FILENAME_NO_EXT"_depth".hdr
    ./DoFFromDepthMap -i $DECOMPRESSED_PATH/$FILENAME -d $DEPTHNAME -o $DECOMPRESSED_PATH_DOF_POST/$FILENAME -f $DEPTH -b 0.1 -s $DOF_STRENGTH
    ./DoFFromDepthMap -i $DECOMPRESSED_PATH_DOF/$FILENAME -d $DEPTHNAME -o $DECOMPRESSED_PATH_DOF_POST/$FILENAME -f $DEPTH -b 0.1 -s $DOF_STRENGTH
    ./DoFFromDepthMap -i $DECOMPRESSED_PATH_DOF_HALF/$FILENAME -d $DEPTHNAME -o $DECOMPRESSED_PATH_DOF_HALF_FINISHED/$FILENAME -f $DEPTH -b 0.1 -s $DOF_STRENGTH
    ./DoFFromDepthMap -i $INPUT_PATH/$FILENAME -d $DEPTHNAME -o $DOF_REFERENCE/$FILENAME -f $DEPTH -b 0.1 -s $DOF_STRENGTH
    ./DoFFromDepthMap -i $DOF_REFERENCE/$FILENAME -d $DEPTHNAME -o $DOF_REFERENCE/$FILENAME -f $DEPTH -b 0.1 -s $DOF_STRENGTH
done
cd -

DOF_PRE=$DECOMPRESSED_PATH_DOF
DOF_POST=$DECOMPRESSED_PATH_DOF_POST
DOF_HALF=$DECOMPRESSED_PATH_DOF_HALF_FINISHED

mkdir -p $OUTPUT_PATH/dofReference
cp -f $DOF_REFERENCE/* $OUTPUT_PATH/dofReference/
mkdir -p $OUTPUT_PATH/dofPre
cp -f $DOF_PRE/* $OUTPUT_PATH/dofPre/
mkdir -p $OUTPUT_PATH/dofPost
cp -f $DOF_POST/* $OUTPUT_PATH/dofPost/
mkdir -p $OUTPUT_PATH/dofHalf
cp -f $DOF_HALF/* $OUTPUT_PATH/dofHalf/
mkdir -p $OUTPUT_PATH/nodofJpegAda
cp -f $DECOMPRESSED_PATH_JPG_ADA/* $OUTPUT_PATH/nodofJpegAda/
mkdir -p $OUTPUT_PATH/nodofJpegFull
cp -f $DECOMPRESSED_PATH_JPG_FULL/* $OUTPUT_PATH/nodofJpegFull/
mkdir -p $OUTPUT_PATH/nodofJpegRef
cp -f $DECOMPRESSED_PATH_JPG_REF/* $OUTPUT_PATH/nodofJpegRef/
mkdir -p $OUTPUT_PATH/nodofReference
cp -f $INPUT_PATH/* $OUTPUT_PATH/nodofReference/
mkdir -p $OUTPUT_PATH/depth
cp -f $INPUT_DEPTH/* $OUTPUT_PATH/depth/

: '

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
BLENDED_JPG_ADA=$TEMP/blendedJpgAda
mkdir $BLENDED_JPG_ADA
BLENDED_JPG_FULL=$TEMP/blendedJpgFull
mkdir $BLENDED_JPG_FULL
BLENDED_JPG_REF=$TEMP/blendedJpgRef
mkdir $BLENDED_JPG_REF
./blendViews.sh $DOF_REFERENCE $BLENDED_DOF_REFERENCE
./blendViews.sh $DOF_PRE $BLENDED_DOF_PRE
./blendViews.sh $DOF_POST $BLENDED_DOF_POST
./blendViews.sh $DOF_HALF $BLENDED_DOF_HALF
./blendViews.sh $INPUT_PATH $BLENDED_NODOF_REF
./blendViews.sh $DECOMPRESSED_PATH $BLENDED_NODOF_DEC
./blendViews.sh $DECOMPRESSED_PATH_JPG_ADA $BLENDED_JPG_ADA
./blendViews.sh $DECOMPRESSED_PATH_JPG_FULL $BLENDED_JPG_FULL
./blendViews.sh $DECOMPRESSED_PATH_JPG_REF $BLENDED_JPG_REF
QUALITY_BLENDED_PRE=$(./measureQuality.sh $BLENDED_DOF_PRE $BLENDED_DOF_REFERENCE $FULL_MEASURE)
QUALITY_BLENDED_POST=$(./measureQuality.sh $BLENDED_DOF_POST $BLENDED_DOF_REFERENCE $FULL_MEASURE)
QUALITY_BLENDED_HALF=$(./measureQuality.sh $BLENDED_DOF_HALF $BLENDED_DOF_REFERENCE $FULL_MEASURE)
QUALITY_BLENDED_DEC=$(./measureQuality.sh $BLENDED_NODOF_DEC $BLENDED_NODOF_REF $FULL_MEASURE)
QUALITY_BLENDED_DEC_JPG_ADA=$(./measureQuality.sh $BLENDED_JPG_ADA $BLENDED_JPG_REF $FULL_MEASURE)
QUALITY_BLENDED_DEC_JPG_FULL=$(./measureQuality.sh $BLENDED_JPG_FULL $BLENDED_JPG_REF $FULL_MEASURE)

'

# All blended metric
NAMES=$(find $DOF_REFERENCE -maxdepth 1 | tail -n +2 | tr '\n' ' ')
ALL_BLEND_DOF_REF=$TEMP/allBlendDofRef.png
$MAGICK $NAMES -evaluate-sequence Mean $ALL_BLEND_DOF_REF
NAMES=$(find $DOF_PRE -maxdepth 1 | tail -n +2 | tr '\n' ' ')
ALL_BLEND_DOF_PRE=$TEMP/allBlendDofPre.png
$MAGICK $NAMES -evaluate-sequence Mean $ALL_BLEND_DOF_PRE
NAMES=$(find $DOF_POST -maxdepth 1 | tail -n +2 | tr '\n' ' ')
ALL_BLEND_DOF_POST=$TEMP/allBlendDofPost.png
$MAGICK $NAMES -evaluate-sequence Mean $ALL_BLEND_DOF_POST
NAMES=$(find $DOF_HALF -maxdepth 1 | tail -n +2 | tr '\n' ' ')
ALL_BLEND_DOF_HALF=$TEMP/allBlendDofHalf.png
$MAGICK $NAMES -evaluate-sequence Mean $ALL_BLEND_DOF_HALF
NAMES=$(find $INPUT_PATH -maxdepth 1 | tail -n +2 | tr '\n' ' ')
ALL_BLEND_NODOF_REF=$TEMP/allBlendNoDofRef.png
$MAGICK $NAMES -evaluate-sequence Mean $ALL_BLEND_NODOF_REF
NAMES=$(find $DECOMPRESSED_PATH -maxdepth 1 | tail -n +2 | tr '\n' ' ')
ALL_BLEND_NODOF_DEC=$TEMP/allBlendNoDofDec.png
$MAGICK $NAMES -evaluate-sequence Mean $ALL_BLEND_NODOF_DEC
NAMES=$(find $DECOMPRESSED_PATH_JPG_ADA -maxdepth 1 | tail -n +2 | tr '\n' ' ')
ALL_BLEND_JPG_ADA=$TEMP/allBlendJpgAda.png 
$MAGICK $NAMES -evaluate-sequence Mean $ALL_BLEND_JPG_ADA
NAMES=$(find $DECOMPRESSED_PATH_JPG_FULL -maxdepth 1 | tail -n +2 | tr '\n' ' ')
ALL_BLEND_JPG_FULL=$TEMP/allBlendJpgFull.png
$MAGICK $NAMES -evaluate-sequence Mean $ALL_BLEND_JPG_FULL
NAMES=$(find $DECOMPRESSED_PATH_JPG_REF -maxdepth 1 | tail -n +2 | tr '\n' ' ')
ALL_BLEND_JPG_REF=$TEMP/allBlendJpgRef.png
$MAGICK $NAMES -evaluate-sequence Mean $ALL_BLEND_JPG_REF

QUALITY_ALL_BLENDED_PRE=$(./measureQuality.sh $ALL_BLEND_DOF_PRE $ALL_BLEND_DOF_REF $FULL_MEASURE)
QUALITY_ALL_BLENDED_POST=$(./measureQuality.sh $ALL_BLEND_DOF_POST $ALL_BLEND_DOF_REF $FULL_MEASURE)
QUALITY_ALL_BLENDED_HALF=$(./measureQuality.sh $ALL_BLEND_DOF_HALF $ALL_BLEND_DOF_REF $FULL_MEASURE)
QUALITY_ALL_BLENDED_DEC=$(./measureQuality.sh $ALL_BLEND_NODOF_DEC $ALL_BLEND_NODOF_REF $FULL_MEASURE)
QUALITY_ALL_BLENDED_DEC_JPG_ADA=$(./measureQuality.sh $ALL_BLEND_JPG_ADA $ALL_BLEND_JPG_REF $FULL_MEASURE)
QUALITY_ALL_BLENDED_DEC_JPG_FULL=$(./measureQuality.sh $ALL_BLEND_JPG_FULL $ALL_BLEND_JPG_REF $FULL_MEASURE)

: '

# Native metric
mkdir $TEMP/native
cd $QUILT_TO_NATIVE
#./QuiltToNative -i $DOF_PRE -o $TEMP/native -cols $VIEW_COUNT -rows 1 -width 1536 -height 2048 -pitch 246.867 -tilt -0.185828 -center 0.350117 -viewPortion 1 -subp 0.000217014 -focus 0
#mv $TEMP/native/output.png $TEMP/nativePre.png
#./QuiltToNative -i $DOF_POST -o $TEMP/native -cols $VIEW_COUNT -rows 1 -width 1536 -height 2048 -pitch 246.867 -tilt -0.185828 -center 0.350117 -viewPortion 1 -subp 0.000217014 -focus 0
#mv $TEMP/native/output.png $TEMP/nativePost.png
#./QuiltToNative -i $DOF_HALF -o $TEMP/native -cols $VIEW_COUNT -rows 1 -width 1536 -height 2048 -pitch 246.867 -tilt -0.185828 -center 0.350117 -viewPortion 1 -subp 0.000217014 -focus 0
#mv $TEMP/native/output.png $TEMP/nativeHalf.png
#./QuiltToNative -i $DOF_REFERENCE -o $TEMP/native -cols $VIEW_COUNT -rows 1 -width 1536 -height 2048 -pitch 246.867 -tilt -0.185828 -center 0.350117 -viewPortion 1 -subp 0.000217014 -focus 0
#mv $TEMP/native/output.png $TEMP/nativeRef.png
./QuiltToNative -i $INPUT_PATH -o $TEMP/native -cols $VIEW_COUNT -rows 1 -width 1536 -height 2048 -pitch 246.867 -tilt -0.185828 -center 0.350117 -viewPortion 1 -subp 0.000217014 -focus 0
mv $TEMP/native/output.png $TEMP/nativeNodofRef.png
./QuiltToNative -i $DECOMPRESSED_PATH -o $TEMP/native -cols $VIEW_COUNT -rows 1 -width 1536 -height 2048 -pitch 246.867 -tilt -0.185828 -center 0.350117 -viewPortion 1 -subp 0.000217014 -focus 0
mv $TEMP/native/output.png $TEMP/nativeNodofDec.png
./QuiltToNative -i $DECOMPRESSED_PATH_JPG_ADA -o $TEMP/native -cols $VIEW_COUNT -rows 1 -width 1536 -height 2048 -pitch 246.867 -tilt -0.185828 -center 0.350117 -viewPortion 1 -subp 0.000217014 -focus 0
mv $TEMP/native/output.png $TEMP/nativeJpgAda.png
./QuiltToNative -i $DECOMPRESSED_PATH_JPG_FULL -o $TEMP/native -cols $VIEW_COUNT -rows 1 -width 1536 -height 2048 -pitch 246.867 -tilt -0.185828 -center 0.350117 -viewPortion 1 -subp 0.000217014 -focus 0
mv $TEMP/native/output.png $TEMP/nativeJpgFull.png
./QuiltToNative -i $DECOMPRESSED_PATH_JPG_REF -o $TEMP/native -cols $VIEW_COUNT -rows 1 -width 1536 -height 2048 -pitch 246.867 -tilt -0.185828 -center 0.350117 -viewPortion 1 -subp 0.000217014 -focus 0
mv $TEMP/native/output.png $TEMP/nativeJpgRef.png
cd -
#QUALITY_NATIVE_PRE=$(./measureQuality.sh  $TEMP/nativePre.png $TEMP/nativeRef.png $FULL_MEASURE)
#QUALITY_NATIVE_POST=$(./measureQuality.sh  $TEMP/nativePost.png $TEMP/nativeRef.png $FULL_MEASURE)
#QUALITY_NATIVE_HALF=$(./measureQuality.sh  $TEMP/nativeHalf.png $TEMP/nativeRef.png $FULL_MEASURE)
QUALITY_NATIVE_DEC=$(./measureQuality.sh  $TEMP/nativeNodofDec.png $TEMP/nativeNodofRef.png $FULL_MEASURE)
QUALITY_NATIVE_DEC_JPG_ADA=$(./measureQuality.sh  $TEMP/nativeJpg.png $TEMP/nativeJpgRef.png $FULL_MEASURE)
QUALITY_NATIVE_DEC_JPG_FULL=$(./measureQuality.sh  $TEMP/nativeJpgFull.png $TEMP/nativeJpgRef.png $FULL_MEASURE)

# Simulated metric
mkdir $TEMP/simulatedPre
mkdir $TEMP/simulatedPost
mkdir $TEMP/simulatedHalf
mkdir $TEMP/simulatedRef
mkdir $TEMP/simulatedNodofRef
mkdir $TEMP/simulatedNodofDec
mkdir $TEMP/simulatedNodofDecJpgAda
mkdir $TEMP/simulatedNodofDecJpgFull
mkdir $TEMP/simulatedNodofDecJpgRef
mkdir $TEMP/quiltForSim
./simulateViews.sh $DOF_PRE $TEMP/quiltForSim $TEMP/simulatedPre 
./simulateViews.sh $DOF_POST $TEMP/quiltForSim $TEMP/simulatedPost 
./simulateViews.sh $DOF_HALF $TEMP/quiltForSim $TEMP/simulatedHalf 
./simulateViews.sh $DOF_REFERENCE $TEMP/quiltForSim $TEMP/simulatedRef
./simulateViews.sh $INPUT_PATH $TEMP/quiltForSim $TEMP/simulatedNodofRef
./simulateViews.sh $DECOMPRESSED_PATH $TEMP/quiltForSim $TEMP/simulatedNodofDec
./simulateViews.sh $DECOMPRESSED_PATH_JPG_ADA $TEMP/quiltForSim $TEMP/simulatedNodofDecJpgAda
./simulateViews.sh $DECOMPRESSED_PATH_JPG_FULL $TEMP/quiltForSim $TEMP/simulatedNodofDecJpgFull
./simulateViews.sh $DECOMPRESSED_PATH_JPG_REF $TEMP/quiltForSim $TEMP/simulatedNodofDecJpgRef
QUALITY_SIMULATED_PRE=$(./measureQuality.sh  $TEMP/simulatedPre/ $TEMP/simulatedRef/ $FULL_MEASURE)
QUALITY_SIMULATED_POST=$(./measureQuality.sh  $TEMP/simulatedPost/ $TEMP/simulatedRef/ $FULL_MEASURE)
QUALITY_SIMULATED_HALF=$(./measureQuality.sh  $TEMP/simulatedHalf/ $TEMP/simulatedRef/ $FULL_MEASURE)
QUALITY_SIMULATED_DEC=$(./measureQuality.sh  $TEMP/simulatedNodofDec/ $TEMP/simulatedNodofRef/ $FULL_MEASURE)
QUALITY_SIMULATED_DEC_JPG_ADA=$(./measureQuality.sh  $TEMP/simulatedNodofDecJpgAda/ $TEMP/simulatedNodofDecJpgRef/ $FULL_MEASURE)

'

# Simple decoding metric
#QUALITY_DECODED_PRE=$(./measureQuality.sh $DOF_PRE $DOF_REFERENCE $FULL_MEASURE)
#QUALITY_DECODED_POST=$(./measureQuality.sh $DOF_POST $DOF_REFERENCE $FULL_MEASURE)
#QUALITY_DECODED_HALF=$(./measureQuality.sh $DOF_HALF $DOF_REFERENCE $FULL_MEASURE)
#QUALITY_DECODED_DEC=$(./measureQuality.sh $DECOMPRESSED_PATH $INPUT_PATH $FULL_MEASURE)
#QUALITY_DECODED_JPG_ADA=$(./measureQuality.sh $DECOMPRESSED_PATH_JPG_ADA $DECOMPRESSED_PATH_JPG_REF $FULL_MEASURE)
#QUALITY_DECODED_JPG_FULL=$(./measureQuality.sh $DECOMPRESSED_PATH_JPG_FULL $DECOMPRESSED_PATH_JPG_REF $FULL_MEASURE)

echo "Results"
echo "Focus depth:"
echo $DEPTH
echo "____________"

echo "No dof"
echo -n "Size:"
PRE_SIZE=$(stat --printf="%s" $TEMP/compressed.mkv)
echo $PRE_SIZE
echo -n "Decoded:"
echo $QUALITY_DECODED_DEC
echo -n "Blended partially:"
echo $QUALITY_BLENDED_DEC
echo -n "Blended all:"
echo $QUALITY_ALL_BLENDED_DEC
echo -n "Native:"
echo $QUALITY_NATIVE_DEC
echo -n "Simulated:"
echo $QUALITY_SIMULATED_DEC
echo "____________"

echo "No dof JPG"
echo -n "Size:"
JPG_SIZE=$(stat --printf="%s" $TEMP/compressedJpgFull.mkv)
echo $JPG_SIZE
echo -n "Decoded:"
echo $QUALITY_DECODED_JPG_FULL
echo -n "Blended partially:"
echo $QUALITY_BLENDED_DEC_JPG_FULL
echo -n "Blended all:"
echo $QUALITY_ALL_BLENDED_DEC_JPG_FULL
echo -n "Native:"
echo $QUALITY_NATIVE_DEC_JPG_FULL
echo -n "Simulated:"
echo $QUALITY_SIMULATED_DEC_JPG_FULL
echo "____________"

echo "No dof JPG depth-aware"
echo -n "Size:"
JPG_SIZE=$(stat --printf="%s" $TEMP/compressedJpgAdaptive.mkv)
echo $JPG_SIZE
echo -n "Decoded:"
echo $QUALITY_DECODED_JPG_ADA
echo -n "Blended partially:"
echo $QUALITY_BLENDED_DEC_JPG_ADA
echo -n "Blended all:"
echo $QUALITY_ALL_BLENDED_DEC_JPG_ADA
echo -n "Native:"
echo $QUALITY_NATIVE_DEC_JPG_ADA
echo -n "Simulated:"
echo $QUALITY_SIMULATED_DEC_JPG_ADA
echo "____________"

echo "Pre"
echo -n "Size:"
PRE_SIZE=$(stat --printf="%s" $TEMP/compressedDof.mkv)
echo $PRE_SIZE
echo -n "Decoded:"
echo $QUALITY_DECODED_PRE
echo -n "Blended partially:"
echo $QUALITY_BLENDED_PRE
echo -n "Blended all:"
echo $QUALITY_ALL_BLENDED_PRE
echo -n "Native:"
echo $QUALITY_NATIVE_PRE
echo -n "Simulated:"
echo $QUALITY_SIMULATED_PRE
echo "____________"

echo "Post"
echo -n "Size:"
POST_SIZE=$(stat --printf="%s" $TEMP/compressed.mkv)
echo $POST_SIZE
echo -n "Decoded:"
echo $QUALITY_DECODED_POST
echo -n "Blended partially:"
echo $QUALITY_BLENDED_POST
echo -n "Blended all:"
echo $QUALITY_ALL_BLENDED_POST
echo -n "Native:"
echo $QUALITY_NATIVE_POST
echo -n "Simulated:"
echo $QUALITY_SIMULATED_POST
echo "____________"

echo "Half"
echo -n "Size:"
HALF_SIZE=$(stat --printf="%s" $TEMP/compressedDofHalf.mkv)
echo $HALF_SIZE
echo -n "Decoded:"
echo $QUALITY_DECODED_HALF
echo -n "Blended partially:"
echo $QUALITY_BLENDED_HALF
echo -n "Blended all:"
echo $QUALITY_ALL_BLENDED_HALF
echo -n "Native:"
echo $QUALITY_NATIVE_HALF
echo -n "Simulated:"
echo $QUALITY_SIMULATED_HALF

rm -rf $TEMP
