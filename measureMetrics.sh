#!/bin/bash
INPUT=$1
OUTPUT_REPORT=$2
OUTPUT_REPORT_BLEND=$3
OUTPUT_DIR_DECOMP=$4
FFMPEG=ffmpeg
VVCENC=./vvenc/bin/release-static/vvencapp
VVCDEC=./vvdec/bin/release-static/vvdecapp
ENCODER_OPTIONS="-rs 2 -c yuv420 --preset medium --qpa 1"
TEMP=$(mktemp -d)
BLENDED=$TEMP/blended
mkdir $BLENDED

for CRF in 0 9 18 27 36 45 54; do 
	$FFMPEG -y -i $INPUT/%04d.png $TEMP/temp.y4m
    rm -f $TEMP/temp.266
	$VVCENC -i $TEMP/temp.y4m $ENCODER_OPTIONS $CRF -o $TEMP/temp.266
	$FFMPEG -y -strict -2 -i $TEMP/temp.266 $OUTPUT_DIR_DECOMP/%04d.png

    QUALITY=$(./measureQuality.sh $OUTPUT_DIR_DECOMP $INPUT 1)
    SIZE=$(stat --printf="%s" $TEMP/temp.266)
    echo $CRF,$QUALITY,$SIZE > $OUTPUT_REPORT

    ./blendViews.sh $OUTPUT_DIR_DECOMP $BLENDED
    QUALITY=$(./measureQuality.sh $BLENDED $INPUT 1)
    echo $CRF,$QUALITY,$SIZE > $OUTPUT_REPORT_BLEND
done
