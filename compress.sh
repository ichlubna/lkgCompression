FFMPEG=ffmpeg
VVCENC=./vvenc/bin/release-static/vvencapp
VVCDEC=./vvdec/bin/release-static/vvdecapp
MAGICK=magick
ZIP=7z
TEMP=$(mktemp -d)
Q_FRONT=30
Q_BACK=50
Q_MASK=50
BACK_FILTER="scale=iw*.5:ih*.5"

function compressFront ()
{
	$FFMPEG -y -i $1 -pix_fmt yuv420p $TEMP/temp.y4m
	$VVCENC -i $TEMP/temp.y4m -c yuv420 -q $Q_FRONT -o $2
}

function compressBack ()
{
	$FFMPEG -y -i $1 -pix_fmt yuv420p $TEMP/temp.y4m
	$VVCENC -i $TEMP/temp.y4m -c yuv420 -q $Q_BACK -o $2
}

function compressMasks ()
{
	$FFMPEG -y -i $1 -pix_fmt yuv420p $TEMP/temp.y4m
	$VVCENC -i $TEMP/temp.y4m -c yuv420 -q $Q_MASK -o $2
}

function decompress ()
{
	#$VVCDEC -b $1 --y4m -o $TEMP/temp.y4m
	#$FFMPEG -y -i $TEMP/temp.y4m $2
	$FFMPEG -y -strict -2 -i $1 $2
}

FRONT_INPUT=front
BACK_INPUT=back
FULL_INPUT=full
MASKS_INPUT=masks
BLUR_INPUT=blurMasks

BACK_COMP=$TEMP/compressedBack.266
FRONT_COMP=$TEMP/compressedFront.266
FULL_COMP=$TEMP/compressedFull.266
MASKS_COMP=$TEMP/compressedMasks.mkv
compressBack $BACK_INPUT/%04d.png $BACK_COMP
compressFront $FRONT_INPUT/%04d.png $FRONT_COMP
compressFront $FULL_INPUT/%04d.png $FULL_COMP
compressMasks $MASKS_INPUT/%04d.png $MASKS_COMP
BACK_DECOMP=$TEMP/decompressedBack
FRONT_DECOMP=$TEMP/decompressedFront
FULL_DECOMP=$TEMP/decompressedFull
MASKS_DECOMP=$TEMP/decompressedMasks
mkdir $BACK_DECOMP
mkdir $FRONT_DECOMP
mkdir $FULL_DECOMP
mkdir $MASKS_DECOMP
decompress $BACK_COMP $BACK_DECOMP/%04d.png
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

#Parameters: input image, blur mask, output image
function fakeDoF ()
{
	$MAGICK $1 $2 -compose blur -define compose:args=10 -composite $3
}

FULL_DOF=$TEMP/fullDoF
mkdir $FULL_DOF
for FILE in $FULL_INPUT/*.png; do
	FILENAME=$(basename $FILE)
	fakeDoF $MERGED_DECOMP/$FILENAME $BLUR_INPUT/$FILENAME $MERGED_DECOMP/$FILENAME
	fakeDoF $FULL_DECOMP/$FILENAME $BLUR_INPUT/$FILENAME $FULL_DECOMP/$FILENAME
	fakeDoF $FULL_INPUT/$FILENAME $BLUR_INPUT/$FILENAME $FULL_DOF/$FILENAME
	
done

BLENDED_SPLIT_DECOMP=$TEMP/blendedDecompressed
BLENDED_FULL_DECOMP=$TEMP/blendedFullDecompressed
BLENDED_FULL=$TEMP/blendedFull
mkdir $BLENDED_SPLIT_DECOMP
mkdir $BLENDED_FULL_DECOMP
mkdir $BLENDED_FULL
COUNT=$(ls -1q $FULL_DECOMP/*.png | wc -l)
for (( I=2; I<=$((COUNT-1)); I++ )); do
	FILENAME_PREV=$(printf "%04d\n" $((I-1))).png
	FILENAME_CUR=$(printf "%04d\n" $((I))).png
	FILENAME_NEXT=$(printf "%04d\n" $((I+1))).png
	$MAGICK $MERGED_DECOMP/$FILENAME_PREV $MERGED_DECOMP/$FILENAME_CUR $MERGED_DECOMP/$FILENAME_NEXT -evaluate-sequence Mean $BLENDED_SPLIT_DECOMP/$FILENAME_CUR
	$MAGICK $FULL_DECOMP/$FILENAME_PREV $FULL_DECOMP/$FILENAME_CUR $FULL_DECOMP/$FILENAME_NEXT -evaluate-sequence Mean $BLENDED_FULL_DECOMP/$FILENAME_CUR
	$MAGICK $FULL_DOF/$FILENAME_PREV $FULL_DOF/$FILENAME_CUR $FULL_DOF/$FILENAME_NEXT -evaluate-sequence Mean $BLENDED_FULL/$FILENAME_CUR
done
BLENDED_ALL_SPLIT_DECOMP=$TEMP/blendedAllSplit.png
BLENDED_ALL_FULL_DECOMP=$TEMP/blendedAllFullDecomp.png
BLENDED_ALL_FULL=$TEMP/blendedAllFull.png
TO_BLEND=$(find $MERGED_DECOMP/* -maxdepth 0 -printf "%p ")
$MAGICK $TO_BLEND -evaluate-sequence Mean $BLENDED_ALL_SPLIT_DECOMP
TO_BLEND=$(find $FULL_DECOMP/* -maxdepth 0 -printf "%p ")
$MAGICK $TO_BLEND -evaluate-sequence Mean $BLENDED_ALL_FULL_DECOMP
TO_BLEND=$(find $FULL_DOF/* -maxdepth 0 -printf "%p ")
$MAGICK $TO_BLEND -evaluate-sequence Mean $BLENDED_ALL_FULL

#Parameters: decompressed images, reference images
function measureQuality ()
{
	RESULT=$(ffmpeg -i $1 -i $2 -filter_complex "psnr" -f null /dev/null 2>&1)
	PSNR=$(echo "$RESULT" | grep -oP '(?<=average:).*?(?= min)')
	echo $PSNR
}

echo "Results"
echo "Full compression"
echo -n "Size:"
echo $(stat --printf="%s" $FULL_COMP)
echo -n "Decoded:"
measureQuality $FULL_DECOMP/%04d.png $FULL_DOF/%04d.png
echo -n "Blended partially:"
measureQuality $BLENDED_FULL_DECOMP/%04d.png $BLENDED_FULL/%04d.png
echo -n "Blended all:"
measureQuality $BLENDED_ALL_FULL_DECOMP $BLENDED_ALL_FULL

ARCHIVE=$TEMP/archive.7z
$ZIP a -m0=lzma2 -mx $ARCHIVE  $BACK_COMP $FRONT_COMP $MASKS_COMP
echo "Adaptive compression"
echo -n "Size:"
echo $(stat --printf="%s" $ARCHIVE)
echo -n "Decoded:"
measureQuality $MERGED_DECOMP/%04d.png $FULL_DOF/%04d.png
echo -n "Blended partially:"
measureQuality $BLENDED_SPLIT_DECOMP/%04d.png $BLENDED_FULL/%04d.png
echo -n "Blended all:"
measureQuality $BLENDED_ALL_SPLIT_DECOMP $BLENDED_ALL_FULL

rm -rf $TEMP
