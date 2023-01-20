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
#

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

RETINA_2X_MODE_DETECTED=0
DEFAULT_APP_WIDTH=1100
DEFAULT_APP_HEIGHT=775

# store state of xtrace option.
TRACESTATE="$(shopt -po xtrace)"

# Debug helpers
touch "${INSTALL_DIR}runtimestamp"

# Include additional info if tracing turned on
if [[ "${TRACESTATE}" == 'set -o xtrace' ]] ; then
    echo "$@" > "${INSTALL_DIR}args"
    echo "$WORKDIR" > "${INSTALL_DIR}workdir"
    echo "$GCODE" > "${INSTALL_DIR}gcode"
fi

### Get Window ID for Simplify3D window

winidinfo=$(${GETWINDOWID} Simplify3D --list | grep Simplify3D)
# "Simplify3D (Licensed to Firstname Lastname)" size=1100x775 id=1033

# Check that Simplify3D was found
if [ $? -eq 1 ] ; then
    echo "Could not find Simplify3D window. Exiting with error"
    exit 1
fi

# extract window width and height
if [[ "$winidinfo" =~ size\=([0-9]+)x([0-9]+) ]] ; then
    appwidth=${BASH_REMATCH[1]}
    appheight=${BASH_REMATCH[2]}
else
    appwidth=$DEFAULT_APP_WIDTH
    appheight=$DEFAULT_APP_HEIGHT
fi

# get window ID
if [[ "$winidinfo" =~ id\=([0-9]+) ]] ; then
    winid=${BASH_REMATCH[1]}
else
    winid=root
fi

# get windows title - not currently used
#
# screencapture accepts a window title, but window ID is all that is needed
if [[ "$winidinfo" =~ \"([^\"]+)\" ]] ; then
    wintitle=${BASH_REMATCH[1]}
else
    wintitle=""
    echo "$wintitle - No window title found"
fi

"${SCREENCAPTURE}" -x -o -l${winid} "${WORKDIR}window.png"
#     -T <seconds> Take the picture after a delay of <seconds>, default is
#     -x           Do not play sounds.
#     -o           In window capture mode, do not capture the shadow of the window.
#     -l <windowid> Captures the window with windowid.

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
# include image dimensions and length of base64 encode string
echo "${bigthumbdim} ${#OUTPUT}"
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
