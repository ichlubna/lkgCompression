#!/bin/bash
for FILE in $1/*; do 
    if [[ -d $FILE ]]; then
        #./measureMetrics.sh $FILE/full/ $FILE/decompressed.csv $FILE/decompressedBlended.csv $FILE/decompressed/
        #./measureMetricsEDIT.sh $FILE/full/ $FILE/decompressedNew.csv $FILE/decompressedBlendedNew.csv $FILE/decompressed/
        #./compress.sh $FILE/full/ 0
        #./compress.sh $FILE/full/ 9
        #./compress.sh $FILE/full/ 18
        #./compress.sh $FILE/full/ 27
        #./compress.sh $FILE/full/ 36
        #./compress.sh $FILE/full/ 45
        #./compress.sh $FILE/full/ 54
        
        ./compress.sh $FILE/full 0 0
        #./saliencyFocus.sh $FILE/full 
    fi
done
