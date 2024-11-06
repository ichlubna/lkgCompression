MAGICK=magick
INPUT=$1
OUTPUT=$2
COUNT=$(ls -1q $INPUT | wc -l)
FILES=($( ls $INPUT )) 
IMG_ID=1
for (( WIN=5; WIN<=10; WIN++ )); do
    for (( START=0; START<$((COUNT-WIN)); START++ )); do
    FILENAMES=""
        for (( I=$START; I<$((START+WIN)); I++ )); do
            FILENAMES+=$INPUT/${FILES[$I]}" "
        done
    BLENDED_FILENAME=$(printf "%04d\n" $((IMG_ID))).png
    IMG_ID=$((IMG_ID+1))
    $MAGICK $FILENAMES -evaluate-sequence Mean $OUTPUT/$BLENDED_FILENAME
    done
done
