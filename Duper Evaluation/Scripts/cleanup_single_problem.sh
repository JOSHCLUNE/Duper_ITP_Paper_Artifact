#!/bin/sh

(sed '/^[[:blank:]]*%/d;s/%.*//' $1) | awk '{$1=$1};1' 
