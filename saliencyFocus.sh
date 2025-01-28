#!/bin/bash
#set -x
#set -e
INPUT=$(realpath $1)
TEMP=$(mktemp -d)
# https://github.com/zzhanghub/gicd
GICD=/home/ichlubna/Workspace/gicd
# https://github.com/LiheYoung/Depth-Anything
DEPTH_ANYTHING=/home/ichlubna/Workspace/Depth-Anything

startTime=`date +%s.%N`
DEPTHS=$TEMP/inputDepth
mkdir $DEPTHS
INPUT_PNG=$TEMP/pngs
mkdir $INPUT_PNG
cd $DEPTH_ANYTHING
ffmpeg -i $INPUT/%04d.png -pix_fmt rgba $INPUT_PNG/%04d.png
python run.py --encoder vitl --img-path $INPUT_PNG --outdir $DEPTHS --grayscale --pred-only
cd -
endTime=`date +%s.%N`
echo "Time of depth maps:"
echo $( echo "$endTime - $startTime" | bc -l )

startTime=`date +%s.%N`
SALIENCY=$TEMP/saliency
INPUT_FOLDERS=$TEMP/input
mkdir -p $INPUT_FOLDERS
mkdir -p $SALIENCY
cp -r $INPUT $INPUT_FOLDERS/
cd $GICD
CUDA_VISIBLE_DEVICES=0 python test.py --model GICD --input_root $INPUT_FOLDERS --param_path ./gicd_ginet.pth --save_root $SALIENCY
cd -
SALIENCY_OUTPUT=$SALIENCY/*
NAMES=$(find ${SALIENCY_OUTPUT[0]} -maxdepth 1 | tail -n +2 | tr '\n' ' ')
ALL_BLEND=$TEMP/allBlend.png 
magick $NAMES -evaluate-sequence Mean $ALL_BLEND
COORDS=$(magick identify -precision 5 -define identify:locate=maximum -define identify:limit=3 $ALL_BLEND | grep Gray: | sed 's/.*\ //')
endTime=`date +%s.%N`
echo "Time of saliency maps:"
echo $( echo "$endTime - $startTime" | bc -l )

startTime=`date +%s.%N`
NAMES=$(find $DEPTHS -maxdepth 1 | tail -n +2 | tr '\n' ' ')
ALL_BLEND_DEPTH=$TEMP/allBlendDepth.png 
magick $NAMES -evaluate-sequence Mean $ALL_BLEND_DEPTH

MAXIMUM=$(magick $ALL_BLEND -crop +${COORDS/,/+} -format "%[fx:u.r]" info:)
TOLERANCE=5
MAXIMUM=$(bc <<< "scale=4; $MAXIMUM*100") 
MAXIMUM_TOLER=$(bc <<< "scale=4; $MAXIMUM-$TOLERANCE") 
magick $ALL_BLEND -color-threshold "gray($MAXIMUM_TOLER%)-gray($MAXIMUM%)" $TEMP/mask.png
magick $ALL_BLEND_DEPTH -alpha on \( +clone -channel a -fx 0 \) +swap $TEMP/mask.png -composite $TEMP/maskedDepth.png
DEPTH=$(magick $TEMP/maskedDepth.png -resize 1x1! -alpha off -depth 8 -format "%[pixel:p{0,0}]" info:)
DEPTH=$(echo $DEPTH | awk -F[\(\)] '{print $2}')

START=$(magick identify -precision 5 -define identify:locate=minimum -define identify:limit=3 $ALL_BLEND_DEPTH | grep Gray: | cut -d "(" -f2 | cut -d ")" -f1)
END=$(magick identify -precision 5 -define identify:locate=maximum -define identify:limit=3 $ALL_BLEND_DEPTH | grep Gray: | cut -d "(" -f2 | cut -d ")" -f1)
DEPTH_NOR=$(bc <<< "scale=5; ($DEPTH-255*$START)/(255*$END-255*$START)")
endTime=`date +%s.%N`
echo "Time of processing:"
echo $( echo "$endTime - $startTime" | bc -l )

echo "Average potentially focused depth, normalized depth, at coords:"
echo $DEPTH
echo $DEPTH_NOR
echo $COORDS

echo "$INPUT $DEPTH_NOR" >> test.txt
./getDepthAt.sh $INPUT $COORDS $DEPTHS
rm -rf $TEMP
