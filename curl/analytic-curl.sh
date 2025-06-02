#!/bin/bash

URL=$1
[[ $URL == "" ]] && { echo -e "[\033[31m❌\033[0m] Missing URL"; exit; }

curl -o /dev/null -s -w "@curl-format.txt" $URL
