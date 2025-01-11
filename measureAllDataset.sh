#!/bin/bash
for FILE in $1/*; do 
    if [[ -d $FILE ]]; then
        #./measureMetrics.sh $FILE/full/ $FILE/decompressed.csv $FILE/decompressedBlended.csv $FILE/decompressed/
        #./measureMetricsEDIT.sh $FILE/full/ $FILE/decompressedNew.csv $FILE/decompressedBlendedNew.csv $FILE/decompressed/
        ./compress.sh $FILE 0
        ./compress.sh $FILE 9
        ./compress.sh $FILE 18
        ./compress.sh $FILE 27
        ./compress.sh $FILE 36
        ./compress.sh $FILE 45
        ./compress.sh $FILE 54
    fi
done
