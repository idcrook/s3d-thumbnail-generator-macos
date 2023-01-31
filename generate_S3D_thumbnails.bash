#!/bin/bash -x
#!/bin/bash

## Embed thumbnail previews in gcode for macOS Simplify3D (gcode post-process)
## Version 0.3.0
## David Crook

# USAGE
#
#     generate_S3D_thumbnails.bash  file_to_embed_thumbnails_in.gcode
#
# INSTALL
#
# - requires imagemagick (convert, identify)
# - requires GetWindowID util -  https://github.com/smokris/GetWindowID
#
#   brew install imagemagick
#   brew install smokris/getwindowid/getwindowid

# Assign 1 to save execution trace to file
DEBUG_SAVE_EXECTRACE=0
#DEBUG_SAVE_EXECTRACE=1

SCREENCAPTURE="/usr/sbin/screencapture"
BASE64="/usr/bin/base64"

bpfix="/usr/local"
# try to auto-handle case of Apple Silicon Mac Homebrew installation
if [ -x /opt/homebrew/bin/brew ] ; then
    bpfix="$(/opt/homebrew/bin/brew --prefix)"
fi

# assumes these installed using Homebrew
GETWINDOWID="${bpfix}/bin/GetWindowID"
CONVERT="${bpfix}/bin/convert"
IDENTIFY="${bpfix}/bin/identify"

INSTALL_DIR=`dirname "$0"`/
#INSTALL_DIR="${HOME}/projects/3dprint/s3d-thumbnails/"

# Gcode file is first argument ( "[output_filepath]" )
GCODE="${1:-sample.gcode}"

WORKDIR="$TMPDIR"
#WORKDIR="$INSTALL_DIR"
# always add trailing slash
WORKDIR="${WORKDIR%/}/"

RETINA_2X_MODE_DETECTED=0
DEFAULT_APP_WIDTH=1100
DEFAULT_APP_HEIGHT=775

# store state of xtrace option.
TRACESTATE="$(shopt -po xtrace)"

# Debug helpers
touch "${INSTALL_DIR}runtimestamp"

# Include additional info to files if tracing turned on
if [[ "${TRACESTATE}" == 'set -o xtrace' ]] ; then
    echo "$@" > "${INSTALL_DIR}args"
    echo "$WORKDIR" > "${INSTALL_DIR}workdir"
    echo "$GCODE" > "${INSTALL_DIR}gcode"

    # capture stdout+stderr from this script running
    # https://stackoverflow.com/a/314678
    if [[ "${DEBUG_SAVE_EXECTRACE}" == 1 ]] ; then
        echo Redirecting stdout and stderr to file
        exectrace="${INSTALL_DIR}exectrace"
        exec > "$exectrace"
        exec 2>&1
    fi
fi

### Get Window ID for Simplify3D window

# Run GetWindowID for Simplify3D app

winidinfo=$(${GETWINDOWID} Simplify3D --list | grep Simplify3D)
# "Simplify3D (Licensed to Firstname Lastname)" size=1100x775 id=1033

# If Simplify3D v5 app window is always showing title of "(null)", DELETE app
# from Screen Recording in Security and Privacy in System Preferences/Settings
# app. When it gets added back, this should work properly again (includes
# window title with app name, which we rely upon.)

# Check that Simplify3D was found (i.e., grep was successful)
if [ $? -eq 1 ] ; then
    echo "Could not find Simplify3D window. Exiting with error"
    exit 1
fi

# Was trying to assume lowest window id is app window.  This seems to be true
# in Simplify3D V5, but this is not true in V4, so not using in service of
# working with both.

# ${IFS+"false"} && unset oldifs || oldifs="$IFS"    # Store IFS
# IFS=$'\n' windowidlines=( $(${GETWINDOWID} Simplify3D --list ) )
# ${oldifs+"false"} && unset IFS || IFS="$oldifs"    # restore IFS.
# # Save/restore IFS shell built-in https://unix.stackexchange.com/a/264947

# lowest_id=9999999
# lowest_id_line=""
# #echo ${#windowidlines[@]}
# for idline in "${windowidlines[@]}" ; do
#     #echo $idline
#     if [[ "$idline" =~ id\=([0-9]+) ]] ; then
#         winid=${BASH_REMATCH[1]}
#         if (( $winid < $lowest_id )) ; then
#             lowest_id=$winid
#             lowest_id_line=$idline
#         fi
#     fi
# done

# # Check that Simplify3D was found
# if [ $lowest_id -eq 9999999 ] ; then
#     echo "Could not find Simplify3D window. Exiting with error"
#     exit 1
# fi

# # Set window ID
#if [[ "$lowest_id_line" =~ size\=([0-9]+)x([0-9]+) ]] ;
# if (( $lowest_id < 9999999 )) ; then
#     #echo "Found winid=$lowest_id"
#     winid="$lowest_id"
# else
#     winid=root
# fi

# Get window ID
if [[ "$winidinfo" =~ id\=([0-9]+) ]] ; then
    winid=${BASH_REMATCH[1]}
else
    winid=root
fi

# extract window width and height
if [[ "$winidinfo" =~ size\=([0-9]+)x([0-9]+) ]] ; then
    appwidth=${BASH_REMATCH[1]}
    appheight=${BASH_REMATCH[2]}
else
    appwidth=$DEFAULT_APP_WIDTH
    appheight=$DEFAULT_APP_HEIGHT
fi

"${SCREENCAPTURE}" -tpng -x -o -a -l${winid} "${WORKDIR}window.png"
# -t<format>  image format to create, default is png (other options include pdf, jpg, tiff and other formats)
# -x           Do not play sounds.
# -o           In window capture mode, do not capture the shadow of the window.
# -a           do not include windows attached to selected windows
# -l <windowid> Captures the window with windowid.

winpngdimw=$("${IDENTIFY}" -ping -format '%[w]' "${WORKDIR}window.png")
winpngdimh=$("${IDENTIFY}" -ping -format '%[h]' "${WORKDIR}window.png")

# On display in retina mode the captured "size" is 2x window size
if [[ "${winpngdimw}" == $((appwidth * 2)) && "${winpngdimh}" == $((appheight * 2)) ]]; then
    RETINA_2X_MODE_DETECTED=1
    echo RETINA_2X_MODE_DETECTED=$RETINA_2X_MODE_DETECTED
fi

#########################################################################
# Position the crop bounding box
#
# Can tweak calculations below to match custom Simplify3D window layout
########################################################################

# these two are the size of the resulting image crop. here, it calculates
# relative to total dimensions of window captured
cropw=$(( winpngdimw * 3 / 7 ))   #   3/7 or 43%
croph=$(( winpngdimh * 11 / 20 )) #  11/20 or 55%

# these are for the upper left corner (origin) to start the crop, within the
# total window captured
cropwinset=$(( winpngdimw * 7 / 20 ))  # 35%
crophinset=$(( winpngdimh * 2 / 20 ))  # 10%

"${CONVERT}" "${WORKDIR}window.png" -crop ${cropw}x${croph}+${cropwinset}+${crophinset} "${WORKDIR}cropped.png"

########################################################################
## Create two thumbnails
########################################################################
echo "" > "${WORKDIR}base64.txt"

# First thumbnail: a tiny 32x32 px thumbnail
"${CONVERT}" "${WORKDIR}cropped.png" -resize 32x32 "${WORKDIR}sm_thumb.png"

# break the base64 encode into multiple lines (-b -> "break")
b64cmd1="${BASE64} -b 76 -i ${WORKDIR}sm_thumb.png"
set +o xtrace       # turn off debug tracing output
##echo $b64cmd1
OUTPUT=$($b64cmd1)
echo "thumbnail begin 32x32 ${#OUTPUT}" >> "${WORKDIR}base64.txt"
echo "${OUTPUT}" >> "${WORKDIR}base64.txt"
echo "thumbnail end" >> "${WORKDIR}base64.txt"
eval "$TRACESTATE"  # restore state of xtrace option.

# Second thumbnail: takes crop and resizes/scales to 400px wide image
"${CONVERT}" "${WORKDIR}cropped.png" -resize 400x  "${WORKDIR}bigthumb.png"
bigthumbdim=$("${IDENTIFY}" -ping -format '%[w]x%[h]' "${WORKDIR}bigthumb.png")
b64cmd2="${BASE64} -b 76 -i ${WORKDIR}bigthumb.png"
set +o xtrace # turn off debug tracing output
##echo $b64cmd2
OUTPUT=$($b64cmd2)

# Include additional info if tracing turned on
if [[ "${TRACESTATE}" == 'set -o xtrace' ]] ; then
    echo "${bigthumbdim} ${#OUTPUT}" > "${INSTALL_DIR}bigthumbdim"
    echo "${WORKDIR}bigthumb.png" > "${INSTALL_DIR}bigthumbfile"
fi
echo "${bigthumbdim} ${#OUTPUT}"

# include image dimensions and length of base64 encode string
echo "thumbnail begin ${bigthumbdim} ${#OUTPUT}" >> "${WORKDIR}base64.txt"
echo "${OUTPUT}" >> "${WORKDIR}base64.txt"
echo "thumbnail end" >> "${WORKDIR}base64.txt"


eval "$TRACESTATE"  # restore state of xtrace option.

########################################################################
## prepend the thumbnails to original gcode file
########################################################################
# all these lines need to be embedded as gcode comments
sed -i '' 's/^/; /' "${WORKDIR}base64.txt"

cat "${WORKDIR}base64.txt" "$GCODE" > "${WORKDIR}newFile.gcode"
mv "${WORKDIR}newFile.gcode" "$GCODE"
