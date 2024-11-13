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
mkdir -p $BLENDED
BLENDED_DECOMP=$TEMP/blendedDecomp
mkdir -p $BLENDED_DECOMP

for CRF in 0 9 18 27 36 45 54; do 
	$FFMPEG -y -i $INPUT/%04d.png -pix_fmt yuv420p $TEMP/temp.y4m
    rm -f $TEMP/temp.266
	$VVCENC -i $TEMP/temp.y4m $ENCODER_OPTIONS -q $CRF -o $TEMP/temp.266
    DECOMPRESSED=$OUTPUT_DIR_DECOMP/$CRF
    mkdir -p $DECOMPRESSED
	$FFMPEG -y -strict -2 -i $TEMP/temp.266 $DECOMPRESSED/%04d.png

    QUALITY=$(./measureQuality.sh $DECOMPRESSED $INPUT 1)
    SIZE=$(stat --printf="%s" $TEMP/temp.266)
    echo $CRF $QUALITY $SIZE >> $OUTPUT_REPORT

    ./blendViews.sh $DECOMPRESSED $BLENDED
    ./blendViews.sh $INPUT $BLENDED_DECOMP
    QUALITY=$(./measureQuality.sh $BLENDED $BLENDED_DECOMP 1)
    echo $CRF $QUALITY $SIZE >> $OUTPUT_REPORT_BLEND
done

rm -rf $TEMP
