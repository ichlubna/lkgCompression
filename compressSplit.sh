#set -x
#set -e
#!/bin/bash
FFMPEG=ffmpeg
MAGICK=magick
VVCENC=./vvenc/bin/release-static/vvencapp
VVCDEC=./vvdec/bin/release-static/vvdecapp
DOF=/home/ichlubna/Workspace/DoFFromDepthMap/build/
QUILT_TO_NATIVE=/home/ichlubna/Workspace/quiltToNative/build/
BZIP=bzip3
TAR=tar
TEMP=$(mktemp -d)
DOF_FOCUS_DISTANCE=$($MAGICK $1/focus/0001.hdr -format "%[fx:u.r]" info:)
DOF_FOCUS_BOUNDS=$($MAGICK $1/focus/0001.hdr -format "%[fx:u.g]" info:)
#DOF_STRENGTH=35
DOF_STRENGTH=25
Q_FRONT=19
Q_BACK=42
Q_FULL=$(( $Q_FRONT + ($Q_BACK-$Q_FRONT)/2 ))
#Q_FULL=$Q_FRONT
#Q_FULL=$Q_BACK
#Q_FULL=$2
Q_MASK=55
FULL_MEASURE=1
BACK_FILTER="-vf scale=iw*.5:ih*.5:flags=lanczos"
#BACK_FILTER_REVERSE="-vf scale=iw*1.25:ih*1.25:flags=lanczos"
BACK_FILTER=""
BACK_FILTER_REVERSE=""
ENCODER_OPTIONS="-rs 2 -c yuv420 --preset medium --qpa 1"
QUILT_ONLY=0
INPUT_PATH=$1

#Parameters: input, output
function compressFull ()
{
	$FFMPEG -y -i $1 -pix_fmt yuv420p $TEMP/temp.y4m
	$VVCENC -i $TEMP/temp.y4m $ENCODER_OPTIONS -q $Q_FULL -o $2
}

function compressFront ()
{
	$FFMPEG -y -i $1 -pix_fmt yuv420p $TEMP/temp.y4m
	$VVCENC -i $TEMP/temp.y4m $ENCODER_OPTIONS -q $Q_FRONT -o $2
}

function compressBack ()
{
	$FFMPEG -y -i $1 -pix_fmt yuv420p $BACK_FILTER $TEMP/temp.y4m
	$VVCENC -i $TEMP/temp.y4m $ENCODER_OPTIONS -q $Q_BACK -o $2
}

function compressMasks ()
{
	$FFMPEG -y -i $1 -pix_fmt yuv420p $TEMP/temp.y4m
	$VVCENC -i $TEMP/temp.y4m $ENCODER_OPTIONS -q $Q_MASK -o $2
}

function decompress ()
{
	#$VVCDEC -b $1 --y4m -o $TEMP/temp.y4m
	#$FFMPEG -y -i $TEMP/temp.y4m $2
	$FFMPEG -y -strict -2 -i $1 $2
}

function decompressBack ()
{
	$FFMPEG -y -strict -2 -i $1 $BACK_FILTER_REVERSE $2
}

FRONT_INPUT=$INPUT_PATH/front
BACK_INPUT=$INPUT_PATH/back
FULL_INPUT=$INPUT_PATH/full
MASKS_INPUT=$INPUT_PATH/masks
DEPTH_INPUT=$INPUT_PATH/depth

BACK_COMP=$TEMP/compressedBack.mkv
FRONT_COMP=$TEMP/compressedFront.mkv
FULL_COMP=$TEMP/compressedFull.mkv
MASKS_COMP=$TEMP/compressedMasks.mkv
START=$(date +%s.%N)
compressBack $BACK_INPUT/%04d.png $BACK_COMP
compressFront $FRONT_INPUT/%04d.png $FRONT_COMP
compressMasks $MASKS_INPUT/%04d.png $MASKS_COMP
END=$(date +%s.%N)
TIME_COMPR_PROP=$(echo "$END - $START" | bc)
START=$(date +%s.%N)
compressFull $FULL_INPUT/%04d.png $FULL_COMP
END=$(date +%s.%N)
TIME_COMPR_FULL=$(echo "$END - $START" | bc)

BACK_DECOMP=$TEMP/decompressedBack
FRONT_DECOMP=$TEMP/decompressedFront
MASKS_DECOMP=$TEMP/decompressedMasks
FULL_DECOMP=$TEMP/decompressedFull
mkdir $BACK_DECOMP
mkdir $FRONT_DECOMP
mkdir $FULL_DECOMP
mkdir $MASKS_DECOMP
START=$(date +%s.%N)
decompressBack $BACK_COMP $BACK_DECOMP/%04d.png
decompress $FRONT_COMP $FRONT_DECOMP/%04d.png
decompress $MASKS_COMP $MASKS_DECOMP/%04d.png
END=$(date +%s.%N)
TIME_DECOMPR_PROP=$(echo "$END - $START" | bc)
START=$(date +%s.%N)
decompress $FULL_COMP $FULL_DECOMP/%04d.png
END=$(date +%s.%N)
TIME_DECOMPR_FULL=$(echo "$END - $START" | bc)

MERGED_DECOMP=$TEMP/decompressedMerged
mkdir $MERGED_DECOMP
for FILE in $BACK_DECOMP/*.png; do
	FILENAME=$(basename $FILE)
	#$MAGICK $BACK_DECOMP/$FILENAME -channel rgba -alpha set -fuzz $FUZZ -fill none -opaque $KEYCOLOR $TEMP/backTransparent.png
	#$MAGICK $FRONT_DECOMP/$FILENAME -channel rgba -alpha set -fuzz $FUZZ -fill none -opaque $KEYCOLOR $TEMP/frontTransparent.png
	#$MAGICK $TEMP/backTransparent.png $TEMP/frontTransparent.png -compose Over -composite $MERGED_DECOMP/$FILENAME
	$MAGICK composite $FRONT_DECOMP/$FILENAME $BACK_DECOMP/$FILENAME $MASKS_DECOMP/$FILENAME $MERGED_DECOMP/$FILENAME
done

#Parameters: input image, depth map, output image
function fakeDoF ()
{
    DOF_IN=$(realpath $1)
    DOF_DEPTH=$(realpath $2)
    DOF_OUT=$(realpath $3)
    cd $DOF  
    ./DoFFromDepthMap -i $DOF_IN -d $DOF_DEPTH -o $DOF_OUT -f $DOF_FOCUS_DISTANCE -b $DOF_FOCUS_BOUNDS -s $DOF_STRENGTH
    cd -
	#$MAGICK $1 $2 -compose blur -define compose:args=10 -composite $3
}

FULL_DOF=$TEMP/fullDoF
mkdir $FULL_DOF
for FILE in $FULL_INPUT/*.png; do
	FILENAME=$(basename $FILE)
    FILENAME_NO_EXT="${FILENAME%.*}"
	fakeDoF $MERGED_DECOMP/$FILENAME $DEPTH_INPUT/$FILENAME_NO_EXT.hdr $MERGED_DECOMP/$FILENAME
	fakeDoF $FULL_DECOMP/$FILENAME $DEPTH_INPUT/$FILENAME_NO_EXT.hdr $FULL_DECOMP/$FILENAME
	fakeDoF $FULL_INPUT/$FILENAME $DEPTH_INPUT/$FILENAME_NO_EXT.hdr $FULL_DOF/$FILENAME
done

ADAPTIVE_QUILT=./adaptiveCompressionQuilt_qs8x6a0.75.png
$MAGICK montage $MERGED_DECOMP/*.png -tile 8x6 -geometry 420x560+0+0 $ADAPTIVE_QUILT
$MAGICK $ADAPTIVE_QUILT -flop $ADAPTIVE_QUILT
STANDARD_QUILT=./standardCompressionQuilt_qs8x6a0.75.png
$MAGICK montage $FULL_DECOMP/*.png -tile 8x6 -geometry 420x560+0+0 $STANDARD_QUILT
$MAGICK $STANDARD_QUILT -flop $STANDARD_QUILT
FULL_QUILT=./noCompressionQuilt_qs8x6a0.75.png
$MAGICK montage $FULL_DOF/*.png -tile 8x6 -geometry 420x560+0+0 $FULL_QUILT
$MAGICK $FULL_QUILT -flop $FULL_QUILT

if [[ $QUILT_ONLY -eq 1 ]]; then
	rm -rf $TEMP
	exit 0
fi

BLENDED_SPLIT_DECOMP=$TEMP/blendedDecompressed
BLENDED_FULL_DECOMP=$TEMP/blendedFullDecompressed
BLENDED_FULL=$TEMP/blendedFull
mkdir $BLENDED_SPLIT_DECOMP
mkdir $BLENDED_FULL_DECOMP
mkdir $BLENDED_FULL

#./blendViews.sh $MERGED_DECOMP $BLENDED_SPLIT_DECOMP
#./blendViews.sh $FULL_DECOMP $BLENDED_FULL_DECOMP
#./blendViews.sh $FULL_DOF $BLENDED_FULL

NAMES=$(find $MERGED_DECOMP -maxdepth 1 | tail -n +2 | tr '\n' ' ')
#ALL_BLEND_DECOMP=$TEMP/allBlendDecomp.png
#$MAGICK $NAMES -evaluate-sequence Mean $ALL_BLEND_DECOMP
NAMES=$(find $FULL_DECOMP -maxdepth 1 | tail -n +2 | tr '\n' ' ')
ALL_BLEND_FULL_DECOMP=$TEMP/allBlendFullDecomp.png
#$MAGICK $NAMES -evaluate-sequence Mean $ALL_BLEND_FULL_DECOMP
NAMES=$(find $FULL_DOF -maxdepth 1 | tail -n +2 | tr '\n' ' ')
ALL_BLEND_FULL=$TEMP/allBlendFull.png
#$MAGICK $NAMES -evaluate-sequence Mean $ALL_BLEND_FULL

#QUALITY_ALL_BLENDED_FULL=$(./measureQuality.sh $ALL_BLEND_FULL $ALL_BLEND_FULL_DECOMP $FULL_MEASURE)
#QUALITY_ALL_BLENDED_ADA=$(./measureQuality.sh $ALL_BLEND_FULL $ALL_BLEND_DECOMP $FULL_MEASURE)

mkdir $TEMP/native
cd $QUILT_TO_NATIVE
#./QuiltToNative -i $MERGED_DECOMP -o $TEMP/native -cols 8 -rows 6 -width 1536 -height 2048 -pitch 246.867 -tilt -0.185828 -center 0.350117 -viewPortion 1 -subp 0.000217014 -focus 0
#mv $TEMP/native/output.png $TEMP/nativeAda.png
#./QuiltToNative -i $FULL_DECOMP -o $TEMP/native -cols 8 -rows 6 -width 1536 -height 2048 -pitch 246.867 -tilt -0.185828 -center 0.350117 -viewPortion 1 -subp 0.000217014 -focus 0
#mv $TEMP/native/output.png $TEMP/nativeDecomp.png
#./QuiltToNative -i $FULL_DOF -o $TEMP/native -cols 8 -rows 6 -width 1536 -height 2048 -pitch 246.867 -tilt -0.185828 -center 0.350117 -viewPortion 1 -subp 0.000217014 -focus 0
#mv $TEMP/native/output.png $TEMP/nativeFull.png
cd -

mkdir $TEMP/simulatedAda
mkdir $TEMP/simulatedFull
mkdir $TEMP/simulatedRef
mkdir $TEMP/quiltForSim
#./simulateViews.sh $FULL_DOF $TEMP/quiltForSim $TEMP/simulatedRef 
#./simulateViews.sh $FULL_DECOMP $TEMP/quiltForSim $TEMP/simulatedFull 
#./simulateViews.sh $MERGED_DECOMP $TEMP/quiltForSim $TEMP/simulatedAda 

#QUALITY_ALL_NATIVE_FULL=$(./measureQuality.sh  $TEMP/nativeFull.png $TEMP/nativeDecomp.png $FULL_MEASURE)
#QUALITY_ALL_NATIVE_ADA=$(./measureQuality.sh $TEMP/nativeFull.png $TEMP/nativeAda.png $FULL_MEASURE)
#QUALITY_DECODED=$(./measureQuality.sh $FULL_DECOMP $FULL_DOF $FULL_MEASURE)
#QUALITY_BLENDED=$(./measureQuality.sh $BLENDED_FULL_DECOMP $BLENDED_FULL $FULL_MEASURE)
#QUALITY_DECODED_ADA=$(./measureQuality.sh $MERGED_DECOMP $FULL_DOF $FULL_MEASURE)
#QUALITY_BLENDED_ADA=$(./measureQuality.sh $BLENDED_SPLIT_DECOMP $BLENDED_FULL $FULL_MEASURE)
#QUALITY_SIMULATED_FULL=$(./measureQuality.sh  $TEMP/simulatedRef/ $TEMP/simulatedFull/ $FULL_MEASURE)
#QUALITY_SIMULATED_ADA=$(./measureQuality.sh $TEMP/simulatedRef/ $TEMP/simulatedAda/ $FULL_MEASURE)
ARCHIVEA=$TEMP/archiveA.tar
ARCHIVE=$TEMP/archive.tar
$TAR -cvf $ARCHIVEA $BACK_COMP $FRONT_COMP $MASKS_COMP
$BZIP -e -b 511 $ARCHIVEA $ARCHIVE
echo "Results"
echo "Full compression"
echo "Full crf:"
echo $Q_FULL
echo -n "Size:"
FULL_SIZE=$(stat --printf="%s" $FULL_COMP)
echo $FULL_SIZE
#echo -n "Decoded:"
#echo $QUALITY_DECODED
#echo -n "Blended partially:"
#echo $QUALITY_BLENDED
#echo -n "Blended all:"
#echo $QUALITY_ALL_BLENDED_FULL
#echo -n "Native:"
#echo $QUALITY_ALL_NATIVE_FULL
#echo -n "Simulated:"
#echo $QUALITY_SIMULATED_FULL
#echo -n "Compression time: "
#echo $TIME_COMPR_FULL
#echo -n "Decompression time: "
#echo $TIME_DECOMPR_FULL

echo "Adaptive compression"
echo -n "Size:"
ADA_SIZE=$(stat --printf="%s" $ARCHIVE)
echo $ADA_SIZE
#echo -n "Decoded:"
#echo $QUALITY_DECODED_ADA
#echo -n "Blended partially:"
#echo $QUALITY_BLENDED_ADA
#echo -n "Blended all:"
#echo $QUALITY_ALL_BLENDED_ADA
#echo -n "Native:"
#echo $QUALITY_ALL_NATIVE_ADA
#echo -n "Simulated:"
#echo $QUALITY_SIMULATED_ADA
#echo -n "Compression time: "
#echo $TIME_COMPR_PROP
#echo -n "Decompression time: "
#echo $TIME_DECOMPR_PROP

echo Ada ratio: $(echo "scale=4; $ADA_SIZE/$FULL_SIZE*100" | bc -l)%

rm -rf $TEMP
