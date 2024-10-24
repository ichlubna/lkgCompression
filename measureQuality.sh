#!/bin/bash
set -x
TEMP=$(mktemp -d)
FFMPEG=ffmpeg
# https://github.com/richzhang/PerceptualSimilarity
LPIPS=/home/ichlubna/Workspace/PerceptualSimilarity/
# https://github.com/dingkeyan93/DISTS
DISTS=/home/ichlubna//Workspace/DISTS/DISTS_pytorch/
# https://ieeexplore.ieee.org/document/7952356
NIQSV=/home/ichlubna/Workspace/NIQSV-master/build
# https://github.com/zwx8981/LIQE
LIQE=/home/ichlubna/Workspace/LIQE-main
FULL_MEASURE=$3

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

TODO converison top PNG before deep ones

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

measureQuality $1 $2 
rm -rf $TEMP
