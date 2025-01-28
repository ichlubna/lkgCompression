#!/bin/bash
#set -x
INPUT=$(realpath $1)
COORDS=$2
TEMP=$(mktemp -d)
# https://github.com/LiheYoung/Depth-Anything
DEPTH_ANYTHING=/home/ichlubna/Workspace/Depth-Anything

INPUT_DEPTH=$3
if [ -z "$3" ]; then
    INPUT_DEPTH=$TEMP/inputDepth
    mkdir $INPUT_DEPTH
    INPUT_PNG=$TEMP/pngs
    mkdir $INPUT_PNG
    cd $DEPTH_ANYTHING
    ffmpeg -i $INPUT/%04d.png -pix_fmt rgba $INPUT_PNG/%04d.png
    python run.py --encoder vitl --img-path $INPUT_PNG --outdir $INPUT_DEPTH --grayscale --pred-only
    cd -
fi

NAMES=$(find $INPUT_DEPTH -maxdepth 1 | tail -n +2 | tr '\n' ' ')
ALL_BLEND_DEPTH=$TEMP/allBlendDepth.png 
magick $NAMES -evaluate-sequence Mean $ALL_BLEND_DEPTH
#magick $TEMP/inputDepth/0001_depth.png $ALL_BLEND_DEPTH
echo "Potentially focused depth at coords:"
FOCUS=$(magick $ALL_BLEND_DEPTH -crop +${COORDS/,/+} -format "%[fx:round(u.r*255)]" info:)
echo $FOCUS
echo $COORDS
echo "Normalized depth:"
LIMITS=$(./getDepthLimits.sh $ALL_BLEND_DEPTH $COORDS)
LIMITS=($LIMITS)
bc <<< "scale=5; (${LIMITS[2]}-${LIMITS[0]})/(${LIMITS[1]}-${LIMITS[0]})"
rm -rf $TEMP
