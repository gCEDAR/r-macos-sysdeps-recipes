#!/bin/bash

set -e

if [ ! -e build.sh ]; then
    echo "Please run this script from the root of the recipes" >&2
    exit 1
fi

RUN_PKGS=''
FORCE=''

while (( "$#" )); do
    if [ "x$1" = x--tools ]; then RUN_TOOLS=1;
    elif [ "x$1" = x--all ]; then RUN_ALL=1;
    elif [ "x$1" = x--force ]; then FORCE='-f';
    elif [ "x$1" = x-h -o "x$1" = x--help ]; then
        echo ''
        echo " Usage: $0 [-h|--help] --force [--tools | --all] <pkgs. list>"
        echo ''
        echo " Default is --base (r-base-dev), tools include emacs and subversion."
        echo ''
        exit 0
    else
        RUN_PKGS="$RUN_PKGS $1"
    fi
    shift
done

source /etc/os-release

echo "Running OS:"
echo '==========='
echo "        NAME: $NAME"
echo "          ID: $ID"
echo "  VERSION_ID: $VERSION_ID"

export OS_VER="$VERSION_ID"

# for cmake, meson and ninja

if ! command -v cmake > /dev/null; then
    echo "ERROR: cmake not found" >&2
    exit 1
fi

if [ -d $HOME/.local/bin ]; then
    case :$PATH:
        in *:$HOME/bin:*) ;;
        *) export PATH=$PATH:$HOME/.local/bin ;;
    esac
fi

if command -v meson > /dev/null && command -v ninja > /dev/null; then
    echo "ninja and meson are already on the PATH"
else
    PYLIB=$(ls -d ~/.local/bin | tail -n1)
    if [ -z "$PYLIB" ]; then
        echo "ERROR: cannot find Python 3 binaries. Use pip3 install --user meson ninja"
        exit 1
    fi
    export PATH=$PATH:$PYLIB
    if command -v meson > /dev/null && command -v ninja > /dev/null; then
        echo "ninja and meson found in $PYLIB"
    else
        echo "ERROR: cannot find ninja/meson 3 binaries. Use pip3 install --user meson ninja"
        exit 1
    fi
fi

echo "Running build:"
echo '=============='
echo "   RUN_TOOLS: $RUN_TOOLS"
echo "     RUN_ALL: $RUN_ALL"
echo "    RUN_PKGS: $RUN_PKGS"
echo "         TTY: $(tty)"
echo "       FORCE: $FORCE"

## freetype and harfbuzz have a circular dependency
## and need to be bootstrapped in the order FT -> HB -> FT
./build.sh $FORCE -p freetype
./build.sh $FORCE -p harfbuzz
rm -rf build/freetype-2.*

## required
./build.sh $FORCE -p r-base-dev

## NOTE: CRAN R also uses: readline5 pango

## useful
if [ -n "$RUN_TOOLS" ]; then
    ./build.sh $FORCE -p subversion emacs
fi

## all others
if [ -n "$RUN_ALL" ]; then
    ./build.sh $FORCE -p all
elif [ -n "$RUN_PKGS" ]; then
    ./build.sh $FORCE -p $RUN_PKGS
fi

## NOTE: if you want to disable fail-fast, use
## ./build.sh -f -p -- -k all

echo ''
echo "=== DONE"
echo ''
echo 'Consider running scripts/mkdist.pl'
echo ''
