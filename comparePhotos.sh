#!/bin/bash
TEMP=$(mktemp -d)
# This file is generated in Darktable GUI after necessary edits to ensure the image is in the right exposure and cropped.
FIRST=$1
SECOND=$2
XMP_FILE=$3
if [[ -d $1 ]]; then
    FILES=($1/*srw)
    FIRST=${FILES[0]}
    SECOND=${FILES[1]}
    FILES=($1/*xmp)
    XMP_FILE=${FILES[0]}
fi 

darktable-cli $FIRST $XMP_FILE $TEMP/photo1.exr --core --conf plugins/imageio/format/exr/compression=0 1>&2
darktable-cli $SECOND $XMP_FILE $TEMP/photo2.exr --core --conf plugins/imageio/format/exr/compression=0 1>&2
./measureQualityEDIT.sh $TEMP/photo1.exr $TEMP/photo2.exr 1
cp $TEMP/photo1.exr ./photo1.exr
cp $TEMP/photo2.exr ./photo2.exr
rm -rf $TEMP
