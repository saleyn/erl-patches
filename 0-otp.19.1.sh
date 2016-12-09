#!/bin/bash

NEW_VSN=19.1
OLD_PATCH_FILE=1-otp.19.0.patch
NEW_PATCH_FILE=1-otp.${NEW_VSN}.patch

files=()
if [ -f $OLD_PATCH_FILE ]; then
    files=( $OLD_PATCH_FILE )
else
    files=( $(ls *.patch | egrep -v "^1-" | xargs) )
fi

if [ "$1" = "-restore" ]; then
    for p in ${files[@]}; do
        echo
        echo "Restoring files found in $p"
        for f in $(awk '/^\+\+\+/{print $2}' $p); do
            f=${f#*/}
            if [ ! -f $f.orig ]; then
                echo "File $f.orig doesn't exist!"
            else
                cp -v $f.orig $f
            fi
        done
    done
    
    exit 0
fi

[ -f $NEW_PATCH_FILE ] && echo "New patch exists!" && exit 1

echo "Backup original files [y/N]: "
read yn
echo "Overwrite existing *.orig files [y/N]: "
read overwrite

if [ $yn = "y" -o $yn = "Y" ]; then
    for p in ${files[@]}; do
        echo
        echo "Processing $p"
        for f in $(awk '/^\+\+\+/{print $2}' $p); do
            f=${f#*/}
            if [ ! -f $f ]; then
                echo "File $f doesn't exist!"
            elif [ ! -f $f.orig -o "$overwrite" = "y" -o "$overwrite" = "Y" ]; then
                cp -v $f $f.orig
            else
                echo $f skipped
            fi
        done
    done
fi

echo
echo "Apply patches [Y/n]: "
read yn

if [ $yn = "y" -o $yn = "Y" ]; then
    if git status 2>/dev/null 1>&2; then
        echo

        for f in {2..5}-otp*; do
            git apply --stat --check $f
            echo "Apply patch $f [Y/n]: "
            read yn
            if [ $yn = "y" -o $yn = "Y" ]; then
                git apply $f
            else
                echo "Skipped $f"
            fi
        done
    else
        for p in ${files[@]}; do
            echo
            echo "Processing $p"
            patch -p1 < $p
            for f in $(awk '/^\+\+\+/{print $2}' $p) ; do
                f=${f#*/}
                diff -bur $f.orig $f >> $NEW_PATCH_FILE
            done
        done
    fi
fi
