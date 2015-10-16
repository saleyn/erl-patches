#!/bin/bash

OLD_PATCH_FILE=1-otp.17.4.patch
NEW_PATCH_FILE=1-otp.17.5.patch
[ -f $NEW_PATCH_FILE ] && echo "New patch exists!" && exit 1
echo "Backup original files [y/N]: "
read yn
if [ $yn = "y" -o $yn = "Y" ]; then
    for f in $(awk '/\+\+\+/{print $2}' $OLD_PATCH_FILE) ; do cp -v $f $f.orig ; done
fi
echo "Apply patches [Y/n]: "
read yn
if [ $yn = "y" -o $yn = "Y" ]; then
    patch -p0 < $OLD_PATCH_FILE
    for f in $(awk '/\+\+\+/{print $2}' $OLD_PATCH_FILE) ; do
        diff -bur $f.orig $f >> $NEW_PATCH_FILE
    done
fi

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
