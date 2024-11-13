#!/bin/bash
for FILE in $1/*; do 
    if [[ -d $FILE ]]; then
        ./measureMetrics.sh $FILE/full/ $FILE/decompressed.csv $FILE/decompressedBlended.csv $FILE/decompressed/
    fi
done
