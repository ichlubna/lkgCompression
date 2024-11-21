#!/bin/bash
if [ $1 == "wake" ]; then
    STATUS=$(adb shell dumpsys input_method | grep mScreenOn)
    STATUS=$(printf "%s" "${STATUS#*mScreenOn=}" | sed 's/\r$//')
    if [ "$STATUS" == "false" ]; then
        adb shell input keyevent KEYCODE_POWER
    fi
elif [ $1 == "shoot" ]; then
    adb shell "input tap 750 350"
    sleep 1
    adb shell "input tap 1100 200"
elif [ $1 == "get" ]; then
    adb pull storage/extSdCard/DCIM/ photos
    #adb shell rm storage/extSdCard/DCIM/*
fi
