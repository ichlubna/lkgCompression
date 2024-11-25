#!/bin/bash

TS=$(date +%s)
ORDER=measurementOrder$TS.txt
SHUF=measurementOrderShuf$TS.txt
RES=measurementOrderResults$TS.txt
touch $ORDER
touch $SHUF
touch $RES
for DIR in $1/*; do
    FILES=($(ls $DIR/*))
    COUNT=$(ls -1q $DIR | wc -l)
    for ((ID = 1 ; ID < $COUNT ; ID++)); do
        echo ${FILES[(($ID-1))]},${FILES[$ID]} >> $ORDER
    done
done 

shuf $ORDER >> $SHUF

readarray -d "\n" -t CONTENT < $SHUF
for LINE in $CONTENT; do
    magick -size 5x5 xc:black $2/0.png
    magick -size 5x5 xc:black $2/1.png
    readarray -d "," -t TEST_FILES < <(echo $LINE) 
    magick ${TEST_FILES[0]} -gravity North -pointsize 300 -fill blue -annotate +-0+50 '1' $2/0.png
    magick ${TEST_FILES[1]} -gravity North -pointsize 300 -fill blue -annotate +-0+50 '2' $2/1.png
    clear
    ANSWER=""
    read -p "Write 1, 2 to select the better image or nothing if the quality is the same. Confirm by enter: " ANSWER
    SCORE=0
    if [ "$ANSWER" == "1" ]; then
        SCORE=1
    elif [ "$ANSWER" == "2" ]; then
        SCORE=-1
    fi
    echo ${TEST_FILES[0]} ${TEST_FILES[1]} $SCORE >> $RES 
done
