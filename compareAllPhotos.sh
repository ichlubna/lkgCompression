#!/bin/bash
# Using 14px blur in the xmp Darktable settings.
FILES=($( ls -v $1 ))
for i in $(seq 0 6);
do
    QUALITY=$(./comparePhotos.sh $1/${FILES[$i]} $1/${FILES[7]} $1/${FILES[8]})
    echo $QUALITY >> $2
done
