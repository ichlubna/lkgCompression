#!/bin/bash
FFMPEG=ffmpeg
VVCENC=./vvenc/bin/release-static/vvencapp
VVCDEC=./vvdec/bin/release-static/vvdecapp
# https://github.com/richzhang/PerceptualSimilarity
LPIPS=/home/ichlubna/Workspace/PerceptualSimilarity/
# https://github.com/dingkeyan93/DISTS
DISTS=/home/ichlubna//Workspace/DISTS/DISTS_pytorch/
# https://ieeexplore.ieee.org/document/7952356
NIQSV=/home/ichlubna/Workspace/NIQSV-master/build
# https://github.com/zwx8981/LIQE
LIQE=/home/ichlubna/Workspace/LIQE-main
# https://github.com/ichlubna/DoFFromDepthMap
DOF=/home/ichlubna/Workspace/DoFFromDepthMap/build/
MAGICK=magick
ZIP=7z
TEMP=$(mktemp -d)
DOF_FOCUS_DISTANCE=0.15
DOF_FOCUS_BOUNDS=0.0
DOF_STRENGTH=20
Q_FRONT="-q 20"
Q_FULL="-q 19"
Q_BACK="-q 35"
Q_MASK="-q 55"
FULL_MEASURE=0
#BACK_FILTER="-vf scale=iw*.8:ih*.8:flags=lanczos"
#BACK_FILTER_REVERSE="-vf scale=iw*1.25:ih*1.25:flags=lanczos"
BACK_FILTER=""
BACK_FILTER_REVERSE=""
ENCODER_OPTIONS="-rs 2 -c yuv420 --preset medium --qpa 1"
if [[ $# -eq 0 ]]; then
    QUILT_ONLY=0
else
    QUILT_ONLY=$1
fi

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

FRONT_INPUT=front
BACK_INPUT=back
FULL_INPUT=full
MASKS_INPUT=masks
DEPTH_INPUT=depth

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

ADAPTIVE_QUILT=./adaptiveCompressonQuilt_qs8x6a0.75.png
$MAGICK montage $MERGED_DECOMP/*.png -tile 8x6 -geometry 420x560+0+0 $ADAPTIVE_QUILT
$MAGICK $ADAPTIVE_QUILT -flop $ADAPTIVE_QUILT
STANDARD_QUILT=./standardCompressonQuilt_qs8x6a0.75.png
$MAGICK montage $FULL_DECOMP/*.png -tile 8x6 -geometry 420x560+0+0 $STANDARD_QUILT
$MAGICK $STANDARD_QUILT -flop $STANDARD_QUILT

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
COUNT=$(ls -1q $FULL_DECOMP/*.png | wc -l)
IMG_ID=1
for (( WIN=3; WIN<=10; WIN++ )); do
for (( START=0; START<$((COUNT-WIN)); START++ )); do
FILENAMES_MERGED_DECOMP=""
FILENAMES_FULL_DECOMP=""
FILENAMES_FULL=""
for (( I=$START; I<$((START+WIN)); I++ )); do
	FILENAME_CUR=$(printf "%04d\n" $((I+1))).png
    FILENAMES_MERGED_DECOMP+=$MERGED_DECOMP/$FILENAME_CUR" "
    FILENAMES_FULL_DECOMP+=$FULL_DECOMP/$FILENAME_CUR" "
    FILENAMES_FULL+=$FULL_DOF/$FILENAME_CUR" "
done
BLENDED_FILENAME_CUR=$(printf "%04d\n" $((IMG_ID))).png
IMG_ID=$((IMG_ID+1))
$MAGICK $FILENAMES_MERGED_DECOMP -evaluate-sequence Mean $BLENDED_SPLIT_DECOMP/$BLENDED_FILENAME_CUR
$MAGICK $FILENAMES_FULL_DECOMP -evaluate-sequence Mean $BLENDED_FULL_DECOMP/$BLENDED_FILENAME_CUR
$MAGICK $FILENAMES_FULL -evaluate-sequence Mean $BLENDED_FULL/$BLENDED_FILENAME_CUR
done
done

#Parameters: decompressed images, reference images
function measureQuality ()
{
    DISTS_VAL=0
    LPIPS_VAL=0
    NISQ_VAL=0
    LIQE_VAL=0
    PSNR=0
    SSIM=0
    VMAF=0

    TEMP_IMAGE=$TEMP/tempMeasurement.png
    if [[ -d $1 ]]; then
        INPUT_PATTERN=$1/%04d.png
        REF_PATTERN=$2/%04d.png
        if [[ $FULL_MEASURE -eq 1 ]]; then
            for FILE in $1/*.png; do
                FILENAME=$(basename $FILE)
                cd $DISTS
                CURRENT_VAL=$(python DISTS_pt.py --dist $1/$FILENAME --ref $2/$FILENAME 2>/dev/null)
                DISTS_VAL=$(bc -l <<< "$DISTS_VAL + $CURRENT_VAL")
                cd - > /dev/null 
                cd $LPIPS
                CURRENT_VAL=$(python lpips_2imgs.py -p0 $1/$FILENAME -p1 $2/$FILENAME 2>/dev/null)
                CURRENT_VAL=$(printf '%s\n' "${CURRENT_VAL#*Distance: }")
                LPIPS_VAL=$(bc -l <<< "$LPIPS_VAL + $CURRENT_VAL")
                cd - > /dev/null 
                NIQSV_VAL=$($NIQSV/exercise $1/$FILENAME)
                NIQSV_VAL=$(grep -oP '(?<=Score: ).*' <<< "$NIQSV_VAL")
                cd $LIQE
                $FFMPEG -y -i $1/$FILENAME -pix_fmt rgb24 $TEMP_IMAGE
                LIQE_VAL=$(python demo2.py $TEMP_IMAGE 2>/dev/null) 
                cd - > /dev/null 
                LIQE_VAL=$(grep -oP '(?<=quality of).*?(?=as quantified)' <<< "$LIQE_VAL")
            done
            DISTS_VAL=$(bc -l <<< "$DISTS_VAL/$COUNT")
            LPIPS_VAL=$(bc -l <<< "$LPIPS_VAL/$COUNT")
            NIQSV_VAL=$(bc -l <<< "$NIQSV_VAL/$COUNT")
            LIQE_VAL=$(bc -l <<< "$LIQE_VAL/$COUNT")
        fi
    else
        INPUT_PATTERN=$1
        REF_PATTERN=$2
        if [[ $FULL_MEASURE -eq 1 ]]; then
            cd $DISTS
            DISTS_VAL=$(python DISTS_pt.py --dist $1 --ref $2 2>/dev/null)
            cd -  > /dev/null
            cd $LPIPS
            LPIPS_VAL=$(python lpips_2imgs.py -p0 $1 -p1 $2 2>/dev/null)
            LPIPS_VAL=$(printf '%s\n' "${LPIPS_VAL#*Distance: }")
            cd -  > /dev/null
            NIQSV_VAL=$($NIQSV/exercise $1)
            NIQSV_VAL=$(grep -oP '(?<=Score: ).*' <<< "$NIQSV_VAL")
            cd $LIQE
            $FFMPEG -y -i $1/$FILENAME -pix_fmt rgb24 $TEMP_IMAGE 2>/dev/null
            LIQE_VAL=$(python demo2.py $TEMP_IMAGE 2>/dev/null)
            cd - > /dev/null 
            LIQE_VAL=$(grep -oP '(?<=quality of).*?(?=as quantified)' <<< "$LIQE_VAL")
        fi
    fi 
	RESULT=$($FFMPEG -i $INPUT_PATTERN -i $REF_PATTERN -filter_complex "psnr" -f null /dev/null 2>&1)
	PSNR=$(echo "$RESULT" | grep -oP '(?<=average:).*?(?= min)')
    if [[ $FULL_MEASURE -eq 1 ]]; then
        RESULT=$($FFMPEG -i $INPUT_PATTERN -i $REF_PATTERN -filter_complex "ssim" -f null /dev/null 2>&1)
        SSIM=$(echo "$RESULT" | grep -oP '(?<=All:).*?(?= )')
        RESULT=$($FFMPEG -i $INPUT_PATTERN -i $REF_PATTERN -lavfi libvmaf -f null /dev/null 2>&1)
        VMAF=$(echo "$RESULT" | grep -oP '(?<=VMAF score: ).*')
    fi
	echo $PSNR $SSIM $VMAF $DISTS_VAL $LPIPS_VAL $NIQSV_VAL $LIQE_VAL
}

QUALITY_DECODED=$(measureQuality $FULL_DECOMP $FULL_DOF)
QUALITY_BLENDED=$(measureQuality $BLENDED_FULL_DECOMP $BLENDED_FULL)
QUALITY_DECODED_ADA=$(measureQuality $MERGED_DECOMP $FULL_DOF)
QUALITY_BLENDED_ADA=$(measureQuality $BLENDED_SPLIT_DECOMP $BLENDED_FULL)
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
