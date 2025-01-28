#!/bin/bash

START=$(magick identify -precision 5 -define identify:locate=minimum -define identify:limit=3 $1 | grep Red: | cut -d "(" -f2 | cut -d ")" -f1)
END=$(magick identify -precision 5 -define identify:locate=maximum -define identify:limit=3 $1 | grep Red: | cut -d "(" -f2 | cut -d ")" -f1)
FOCUS=$(magick $1 -crop +${2/,/+} -format "%[fx:u.r]" info:)

if [[ -z $START ]] || [[ -z $END ]] || [[ -z $FOCUS ]]; then
START=$(magick identify -precision 5 -define identify:locate=minimum -define identify:limit=3 $1 | grep Gray: | cut -d "(" -f2 | cut -d ")" -f1)
END=$(magick identify -precision 5 -define identify:locate=maximum -define identify:limit=3 $1 | grep Gray: | cut -d "(" -f2 | cut -d ")" -f1)
FOCUS=$(magick $1 -crop +${2/,/+} -format "%[fx:u.g]" info:)
fi
echo $START $END $FOCUS
