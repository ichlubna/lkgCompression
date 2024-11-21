#!/bin/bash
OUT=$(realpath $2)
for FILE in $1/*; do 
    if [[ -d $FILE ]]; then
        DIRNAME=$(basename $FILE)
        FILE=$(realpath $FILE)
        mkdir -p $OUT/$DIRNAME
        for CRF in 0 9 18 27 36 45 54 ../full; do
            cd /home/ichlubna/Workspace/quiltToNative/build/
            ./QuiltToNative -i $FILE/decompressed/$CRF -o ./result -cols 8 -rows 6 -width 1536 -height 2048 -pitch 246.867 -tilt -0.185828 -center 0.350117 -viewPortion 1 -subp 0.000217014 -focus 0
            CRF=$(printf "%02d\n" $CRF)
            cp ./result/output.png $OUT/$DIRNAME/$CRF.png
            cd -
        done
    fi
done
    
