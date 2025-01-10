#!/bin/bash
TEMP_DIR=$(mktemp -d)
TS=$(date +%s)
ORDER=$TEMP_DIR/measurementOrder$TS.txt
SHUF=$TEMP_DIR/measurementOrderShuf$TS.txt
RES=measurementOrderResults$TS.txt
touch $ORDER
touch $SHUF
touch $RES
for DIR in $1/*; do
    FILES=($(ls $DIR/*))
    COUNT=$(ls -1q $DIR | wc -l)
    for ((ID = 1 ; ID <= $COUNT ; ID++)); do
        echo ${FILES[(($ID-1))]},${FILES[$ID]} >> $ORDER
    done
done 

shuf $ORDER >> $SHUF

readarray -d "\n" -t CONTENT < $SHUF
TEST_NUM=0
for LINE in $CONTENT; do
    TEST_NUM=$((TEST_NUM+1))
    echo $TEST_NUM
    continue
    magick -size 5x5 xc:black $2/0.png
    magick -size 5x5 xc:black $2/1.png
    readarray -d "," -t TEST_FILES < <(echo $LINE)
    FIRST=${TEST_FILES[0]} 
    SECOND=${TEST_FILES[1]}
    SWITCHED=0
    if [ $RANDOM -lt 16383 ]; then 
        SWITCHED=1
        TEMP=$FIRST
        FIRST=$SECOND
        SECOND=$TEMP
    fi
    magick $FIRST -gravity North -pointsize 300 -fill blue -annotate +-0+50 '1' $2/0.png
    magick $SECOND -gravity North -pointsize 300 -fill blue -annotate +-0+50 '2' $2/1.png
    clear
    ANSWER=""
    echo "Test #"$TEST_NUM
    TEST_NUM=$((TEST_NUM+1))
    read -p "Write 1, 2 to select the better image or nothing if the quality is the same. Confirm by enter: " ANSWER
    SCORE=0
    if [ "$ANSWER" == "1" ]; then
        SCORE=1
    elif [ "$ANSWER" == "2" ]; then
        SCORE=-1
    fi
    if [ $SWITCHED == 1 ]; then 
        SWITCHED=1
        SCORE=$(( -1 * $SCORE ))
    fi
    echo ${TEST_FILES[0]} ${TEST_FILES[1]} $SCORE >> $RES 
done
rm -rf $TEMP_DIR
