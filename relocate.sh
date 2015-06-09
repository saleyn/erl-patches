#!/bin/sh

##
## For copying/relocating Erlang distribution when configured via:
## ./configure --prefix=/some/place/that/is/not/the/final/installation/dir
##

ONLY_FIX_PATHS=0
TAR_DEL_ARG=""
RELOCATE=0

if [ "$1" = "-d" ]; then
    shift
    TAR_DEL_ARG="--remove-files"
    RELOCATE=1
fi

if [ $# -eq 2 -a "$1" = "-f" ]; then
    if [ ! -e "$2/bin/erl" ]; then
        echo "$2 doesn't seem to have valid Erlang installation!"
        exit 1
    fi
    ONLY_FIX_PATHS=1
    shift
elif [ $# -lt 2 ]; then
    echo "Copying/relocating Erlang installation:"
    echo "   ${0##*/} [-d] src-dir dst-dir [dst-path-dir]"
    echo "   Options:"
    echo "      -d   - delete source files (use this only for relocating files)"
    echo ""
    echo "Fixing paths in Erlang installation copied manually to dst-dir:"
    echo "   ${0##*/} [-f] dst-dir"
    echo ""
    echo "example: ${0##*/} ~/erlang/R12B-4 /opt/erlang-R12B-4"
    echo "NOTE: In most cases, dst-dir and dst-path-dir will be the same."
    echo "      However, in some weird NFS cases, the dst-dir (where"
    echo "      this script will copy files) may be different from"
    echo "      path-dir (where final users will use/execute files)."
    echo "NOTE: Both directories should be absolute paths."
    exit 1
fi

pushd $1; SRCDIR=$PWD; popd
DSTDIR=$2
[ $ONLY_FIX_PATHS -eq 1 ] && DSTDIR=$SRCDIR
pushd $DSTDIR; DSTDIR=$PWD; popd
NEW_ROOTDIR=${3:-$DSTDIR}/lib/erlang

echo "src dir     : $SRCDIR"
echo "dst dir     : $DSTDIR"
echo "root        : $NEW_ROOTDIR"
if [ $ONLY_FIX_PATHS -eq 1 ]; then
    echo "install type: fix paths"
elif [ $RELOCATE -eq 0 ]; then
    echo "install type: copy"
else
    echo "install type: relocate"
fi

echo ""

if [ ! -d $SRCDIR ]; then
    echo "Source directory $SRCDIR does not exist, aborting!"
    exit 1
fi

if [ $ONLY_FIX_PATHS -eq 0 ]; then
    if [ ! -d $DSTDIR ]; then
        echo "Destination directory $DSTDIR does not exist, creating"
        mkdir $DSTDIR
        if [ $? -ne 0 ]; then
            echo "mkdir $DSTDIR failed, aborting!"
            exit 1
        fi
    fi

    echo -n "Copying files from $SRCDIR to $DSTDIR ... "
    rsync -rl $SRCDIR $DSTDIR
    #(cd $SRCDIR ; tar cf - $TAR_DEL_ARG .) | (cd $DSTDIR ; tar xfp -)
    echo "done."

    echo "Performing relocation steps ... "
else
    echo "Adjusting file paths in $DSTDIR ... "
fi

cd $DSTDIR/bin
echo "Entering: $PWD"
TARGET_DIR=../lib/erlang/erts-*/bin
EI_DIR=../lib/erlang/lib/erl_interface*
pushd $TARGET_DIR; TARGET_DIR=$PWD; popd
pushd $EI_DIR; EI_DIR=$PWD; popd

for f in dialyzer epmd erl erlc escript run_erl start to_erl typer erl_call
do
    # Use wildcard to be Erlang-version-flexible (hopefully)
    if [ $f = erl_call ] ; then
        rm -f $f
        ln -vs $EI_DIR/bin/erl_call ./erl_call
    elif [ -h $f -o ! -e $f ]; then
        rm -f $f
        ln -vs $TARGET_DIR/$f ./$f
    fi
done

cd ..
echo "Entering: $PWD"
[ -h ./include ] && rm -f ./include;
ln -vs $EI_DIR/include ./include

cd lib
echo "Entering: $PWD"
rm -f ./tools_emacs
ln -vs erlang/lib/tools-*/emacs $PWD/tools_emacs

for f in erlang/lib/erl_interface*/lib/lib* ; do
    FILE=${f##*/}
    [ -h $FILE ] && rm -f ./$FILE
    ln -vs $f ./$FILE
done

cd $TARGET_DIR
for f in erl start start_erl
do
    perl -np -e "s|%FINAL_ROOTDIR%|$NEW_ROOTDIR|" < $f.src > $f
    if [ -f $DSTDIR/lib/erlang/bin/$f ] ; then
        cp $f $DSTDIR/lib/erlang/bin/$f
    fi
done
echo "done."

echo ""
echo "To use the new runtime environment, add the following directory"
echo "to your shell's PATH variable:"
echo ""
echo "  $DSTDIR/bin"
echo ""

exit 0
