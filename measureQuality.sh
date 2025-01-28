#!/bin/bash
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

#Parameters: decompressed image, reference image, full measurement of not
function measureSingle ()
{
    FIRST_FILE=$(realpath $1)
    SECOND_FILE=$(realpath $2)
    FIRST_FILE_PNG=$TEMP/first.png
    SECOND_FILE_PNG=$TEMP/second.png
    $FFMPEG -y -i $FIRST_FILE -pix_fmt rgb48be $FIRST_FILE_PNG
    $FFMPEG -y -i $SECOND_FILE -pix_fmt rgb48be $SECOND_FILE_PNG
    RESULT=$($FFMPEG -i $FIRST_FILE -i $SECOND_FILE -lavfi libvmaf -f null /dev/null 2>&1)
    VMAF=$(echo "$RESULT" | grep -oP '(?<=VMAF score: ).*')
    VMAF_VAL=$(bc -l <<< "$VMAF_VAL + $VMAF")
    if [[ $FULL_MEASURE -eq 1 ]]; then
		RESULT=$($FFMPEG -i $FIRST_FILE -i $SECOND_FILE -filter_complex "psnr" -f null /dev/null 2>&1)
		PSNR=$(echo "$RESULT" | grep -oP '(?<=average:).*?(?= min)')
		if [ $PSNR_VAL == "inf" ]; then
	    		PSNR_VAL=100
		fi
		PSNR_VAL=$(bc -l <<< "$PSNR_VAL + $PSNR")		
        RESULT=$($FFMPEG -i $FIRST_FILE -i $SECOND_FILE -filter_complex "ssim" -f null /dev/null 2>&1)
        SSIM=$(echo "$RESULT" | grep -oP '(?<=All:).*?(?= )')
        SSIM_VAL=$(bc -l <<< "$SSIM_VAL + $SSIM")
        cd $DISTS
        CURRENT_VAL=$(python DISTS_pt.py --dist $FIRST_FILE_PNG --ref $SECOND_FILE_PNG 2>/dev/null)
        CURRENT_VAL=$(printf '%.10f' $CURRENT_VAL)
        DISTS_VAL=$(bc -l <<< "$DISTS_VAL + $CURRENT_VAL")
        cd - > /dev/null 
        cd $LPIPS
        CURRENT_VAL=$(python lpips_2imgs.py -p0 $FIRST_FILE_PNG -p1 $SECOND_FILE_PNG 2>/dev/null)
        CURRENT_VAL=$(printf '%s\n' "${CURRENT_VAL#*Distance: }")
        CURRENT_VAL=$(printf '%.10f' $CURRENT_VAL)
        LPIPS_VAL=$(bc -l <<< "$LPIPS_VAL + $CURRENT_VAL")
        cd - > /dev/null 
        CURRENT_VAL=$($NIQSV/exercise $FIRST_FILE_PNG)
        CURRENT_VAL=$(grep -oP '(?<=Score: ).*' <<< "$CURRENT_VAL")
        NIQSV_VAL=$(bc -l <<< "$NIQSV_VAL + $CURRENT_VAL")
        cd $LIQE
        CURRENT_VAL=$(python demo2.py $FIRST_FILE_PNG) 
        cd - > /dev/null 
        CURRENT_VAL=$(grep -oP '(?<=quality of).*?(?=as quantified)' <<< "$CURRENT_VAL")
        LIQE_VAL=$(bc -l <<< "$LIQE_VAL + $CURRENT_VAL")
    fi
}

#Parameters: decompressed images, reference images (can be folders)
function measureQuality ()
{
    DISTS_VAL=0
    LPIPS_VAL=0
    NIQSV_VAL=0
    LIQE_VAL=0
    PSNR_VAL=0
    SSIM_VAL=0
    VMAF_VAL=0

    if [[ -d $1 ]]; then
        for FILE in $1/*.png; do
            TRIM_FILE=$(basename $FILE)
            measureSingle $1/$TRIM_FILE $2/$TRIM_FILE
        done
        COUNT=$(ls -1q $1/* | wc -l)
        DISTS_VAL=$(bc -l <<< "$DISTS_VAL/$COUNT")
        LPIPS_VAL=$(bc -l <<< "$LPIPS_VAL/$COUNT")
        NIQSV_VAL=$(bc -l <<< "$NIQSV_VAL/$COUNT")
        LIQE_VAL=$(bc -l <<< "$LIQE_VAL/$COUNT")
        PSNR_VAL=$(bc -l <<< "$PSNR_VAL/$COUNT")
        SSIM_VAL=$(bc -l <<< "$SSIM_VAL/$COUNT")
        VMAF_VAL=$(bc -l <<< "$VMAF_VAL/$COUNT")
    else
        measureSingle $1 $2
    fi 
	echo $PSNR_VAL $SSIM_VAL $VMAF_VAL $DISTS_VAL $LPIPS_VAL $NIQSV_VAL $LIQE_VAL
}

measureQuality $1 $2 
rm -rf $TEMP
