#!/bin/bash
# This file is generated in Darktable GUI after necessary edits to ensure the image is in the right exposure and cropped. Usually stored at the same directory and with the same name as the raw photo.
XMP_FILE=$1.xmp
darktable-cli $1 $XMP_FILE photo1.exr --core --conf plugins/imageio/format/exr/compression=0
darktable-cli $2 $XMP_FILE photo2.exr --core --conf plugins/imageio/format/exr/compression=0
./measureQuality.sh ./photo1.exr ./photo2.exr 1
