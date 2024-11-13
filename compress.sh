#!/bin/bash
FFMPEG=ffmpeg
MAGICK=magick
VVCENC=./vvenc/bin/release-static/vvencapp
VVCDEC=./vvdec/bin/release-static/vvdecapp
DOF=/home/ichlubna/Workspace/DoFFromDepthMap/build/
ZIP=7z
TEMP=$(mktemp -d)
DOF_FOCUS_DISTANCE=0.15
DOF_FOCUS_BOUNDS=0.0
DOF_STRENGTH=20
Q_FRONT="-q 20"
Q_FULL="-q 20"
Q_BACK="-q 35"
Q_MASK="-q 55"
FULL_MEASURE=0
#BACK_FILTER="-vf scale=iw*.8:ih*.8:flags=lanczos"
#BACK_FILTER_REVERSE="-vf scale=iw*1.25:ih*1.25:flags=lanczos"
BACK_FILTER=""
BACK_FILTER_REVERSE=""
ENCODER_OPTIONS="-rs 2 -c yuv420 --preset medium --qpa 1"
QUILT_ONLY=1
INPUT_PATH=$1

#Parameters: input, output
function compressFull ()
{
	$FFMPEG -y -i $1 -pix_fmt yuv420p $TEMP/temp.y4m
	$VVCENC -i $TEMP/temp.y4m $ENCODER_OPTIONS $Q_FULL -o $2
}

function compressFront ()
{
	$FFMPEG -y -i $1 -pix_fmt yuv420p $TEMP/temp.y4m
	$VVCENC -i $TEMP/temp.y4m $ENCODER_OPTIONS $Q_FRONT -o $2
}

function compressBack ()
{
	$FFMPEG -y -i $1 -pix_fmt yuv420p $BACK_FILTER $TEMP/temp.y4m
	$VVCENC -i $TEMP/temp.y4m $ENCODER_OPTIONS $Q_BACK -o $2
}

function compressMasks ()
{
	$FFMPEG -y -i $1 -pix_fmt yuv420p $TEMP/temp.y4m
	$VVCENC -i $TEMP/temp.y4m $ENCODER_OPTIONS $Q_MASK -o $2
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
compressBack $BACK_INPUT/%04d.png $BACK_COMP
compressFront $FRONT_INPUT/%04d.png $FRONT_COMP
compressFull $FULL_INPUT/%04d.png $FULL_COMP
compressMasks $MASKS_INPUT/%04d.png $MASKS_COMP
BACK_DECOMP=$TEMP/decompressedBack
FRONT_DECOMP=$TEMP/decompressedFront
FULL_DECOMP=$TEMP/decompressedFull
MASKS_DECOMP=$TEMP/decompressedMasks
mkdir $BACK_DECOMP
mkdir $FRONT_DECOMP
mkdir $FULL_DECOMP
mkdir $MASKS_DECOMP
decompressBack $BACK_COMP $BACK_DECOMP/%04d.png
decompress $FRONT_COMP $FRONT_DECOMP/%04d.png
decompress $FULL_COMP $FULL_DECOMP/%04d.png
decompress $MASKS_COMP $MASKS_DECOMP/%04d.png

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
./blendViews.sh $MERGED_DECOMP $BLENDED_SPLIT_DECOMP
./blendViews.sh $FULL_DECOMP $BLENDED_FULL_DECOMP
./blendViews.sh $FULL_DOF $BLENDED_FULL

QUALITY_DECODED=$(./measureQuality.sh $FULL_DECOMP $FULL_DOF $FULL_MEASURE)
QUALITY_BLENDED=$(./measureQuality.sh $BLENDED_FULL_DECOMP $BLENDED_FULL $FULL_MEASURE)
QUALITY_DECODED_ADA=$(./measureQuality.sh $MERGED_DECOMP $FULL_DOF $FULL_MEASURE)
QUALITY_BLENDED_ADA=$(./measureQuality.sh $BLENDED_SPLIT_DECOMP $BLENDED_FULL $FULL_MEASURE)
ARCHIVE=$TEMP/archive.7z
$ZIP a -m0=lzma2 -mx $ARCHIVE $BACK_COMP $FRONT_COMP $MASKS_COMP
echo "Results"
echo "Full compression"
echo -n "Size:"
echo $(stat --printf="%s" $FULL_COMP)
echo -n "Decoded:"
echo $QUALITY_DECODED
echo -n "Blended partially:"
echo $QUALITY_BLENDED

echo "Adaptive compression"
echo -n "Size:"
echo $(stat --printf="%s" $ARCHIVE)
echo -n "Decoded:"
echo $QUALITY_DECODED_ADA
echo -n "Blended partially:"
echo $QUALITY_BLENDED_ADA

rm -rf $TEMP
