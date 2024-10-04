FFMPEG=ffmpeg
VVCENC=./vvenc-master/bin/release-static/vvencapp
VVCDEC=./vvdec-master/bin/release-static/vvdecapp
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
	$MAGICK $FULL_INPUT/$FILENAME_PREV $FULL_INPUT/$FILENAME_CUR $FULL_INPUT/$FILENAME_NEXT -evaluate-sequence Mean $BLENDED_FULL/$FILENAME_CUR
done


RESULT=$(ffmpeg -i $FULL_DECOMP/%04d.png -i $FULL_INPUT/%04d.png -filter_complex "psnr" -f null /dev/null 2>&1)
PSNR_FULL=$(echo "$RESULT" | grep -oP '(?<=average:).*?(?= min)')
RESULT=$(ffmpeg -i $BLENDED_FULL_DECOMP/%04d.png -i $BLENDED_FULL/%04d.png -filter_complex "psnr" -f null /dev/null 2>&1)
PSNR_BLENDED_FULL=$(echo "$RESULT" | grep -oP '(?<=average:).*?(?= min)')
SIZE_FULL=$(stat --printf="%s" $FULL_COMP)
RESULT=$(ffmpeg -i $MERGED_DECOMP/%04d.png -i $FULL_INPUT/%04d.png -filter_complex "psnr" -f null /dev/null 2>&1)
PSNR_SPLIT=$(echo "$RESULT" | grep -oP '(?<=average:).*?(?= min)')
RESULT=$(ffmpeg -i $BLENDED_SPLIT_DECOMP/%04d.png -i $BLENDED_FULL/%04d.png -filter_complex "psnr" -f null /dev/null 2>&1)
PSNR_BLENDED_SPLIT=$(echo "$RESULT" | grep -oP '(?<=average:).*?(?= min)')
ARCHIVE=$TEMP/archive.7z
$ZIP a -m0=lzma2 -mx $ARCHIVE  $BACK_COMP $FRONT_COMP $MASKS_COMP
SIZE_BACK=$(stat --printf="%s" $BACK_COMP)
SIZE_FRONT=$(stat --printf="%s" $FRONT_COMP)
SIZE_MASKS=$(stat --printf="%s" $MASKS_COMP)
SIZE_ARCHIVE=$(stat --printf="%s" $ARCHIVE)
echo "Full:"
echo PSNR: $PSNR_FULL
echo Blended PSNR: $PSNR_BLENDED_FULL
echo Size: $SIZE_FULL
echo "Split:"
echo PSNR: $PSNR_SPLIT
echo Blended PSNR: $PSNR_BLENDED_SPLIT
echo Size: $((SIZE_BACK+SIZE_FRONT+SIZE_MASKS))
echo Size zip: $SIZE_ARCHIVE
rm -rf $TEMP
