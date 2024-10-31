#!/bin/bash
TEMP=$(mktemp -d)
# This file is generated in Darktable GUI after necessary edits to ensure the image is in the right exposure and cropped. Usually stored at the same directory and with the same name as the raw photo.
XMP_FILE=$1.xmp
FIRST=$1
SECOND=$2
if [[ -d $1 ]]; then
    FILES=($1/*srw)
    FIRST=${FILES[0]}
    SECOND=${FILES[1]}
    FILES=($1/*xmp)
    XMP_FILE=${FILES[0]}
fi 

darktable-cli $FIRST $XMP_FILE $TEMP/photo1.exr --core --conf plugins/imageio/format/exr/compression=0
darktable-cli $SECOND $XMP_FILE $TEMP/photo2.exr --core --conf plugins/imageio/format/exr/compression=0
./measureQuality.sh $TEMP/photo1.exr $TEMP/photo2.exr 1
cp $TEMP/photo1.exr ./photo1.exr
cp $TEMP/photo2.exr ./photo2.exr
rm -rf $TEMP
