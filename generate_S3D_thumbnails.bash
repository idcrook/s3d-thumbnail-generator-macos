#!/bin/bash -x
#!/bin/bash

## macos 3D print thumbnail generator script

## Version 0.1.2
## David Crook

#
# - requires imagemagick (convert, identify)
# - requires getwindowid util -  https://github.com/smokris/GetWindowID
#
#   brew install imagemagick
#   brew install smokris/getwindowid/getwindowid
#

SCREENCAPTURE="/usr/sbin/screencapture"
BASE64="/usr/bin/base64"

# assumes these installed using Homebrew
bpfix="$(brew --prefix)"
GETWINDOWID="${bpfix}/bin/GetWindowID"
CONVERT="${bpfix}/bin/convert"
IDENTIFY="${bpfix}/bin/identify"

INSTALL_DIR=`dirname "$0"`/
#INSTALL_DIR="${HOME}/projects/3dprint/s3d-thumbnail-generator-macos/"

# Gcode file is first argument
GCODE="${1:-sample.gcode}"

WORKDIR="$TMPDIR"
#WORKDIR="$INSTALL_DIR"

RETINA_2X_MODE_DETECTED=0
TWO_THUMBNAILS=1
DEFAULT_APP_WIDTH=1100
DEFAULT_APP_HEIGHT=775

touch "${INSTALL_DIR}runtimestamp"
echo "$@" > "${INSTALL_DIR}args"
echo "$WORKDIR" > "${INSTALL_DIR}workdir"
echo "$GCODE" > "${INSTALL_DIR}gcode"

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

# screencapture can accept a window title, but window ID (above) is all that is
# needed
if [[ "$winidinfo" =~ \"([^\"]+)\" ]] ; then
    wintitle=${BASH_REMATCH[1]}
else
    wintitle=""
fi

"${SCREENCAPTURE}" -x -o -l${winid} "${WORKDIR}window.png"
#     -T <seconds> Take the picture after a delay of <seconds>, default is
#     -x           Do not play sounds.
#     -o           In window capture mode, do not capture the shadow of the window.
#     -l <windowid> Captures the window with windowid.

# on retina display the "size" is from 2x bitmap
winpngdimw=$("${IDENTIFY}" -ping -format '%[w]' "${WORKDIR}window.png")
winpngdimh=$("${IDENTIFY}" -ping -format '%[w]' "${WORKDIR}window.png")

if [[ "${winpngdimw}" == $((appwidth * 2)) ]]; then
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
cropw=$(( winpngdimw * 3 / 7 ))   #  3/7 or 43%
croph=$(( winpngdimh * 7 / 20 ))  #  7/20 or 35%

# these are for the upper left corner (origin) to start the crop, within the
# total window captured
cropwinset=$(( winpngdimw * 2 / 5 ))  # 40%
crophinset=$(( winpngdimh * 1 / 4 ))  # 25%

"${CONVERT}" "${WORKDIR}window.png" -crop ${cropw}x${croph}+${cropwinset}+${crophinset} "${WORKDIR}cropped.png"

## Two thumbnails may be created

# First thumbnail: a tiny 32x32 px thumbnail
"${CONVERT}" "${WORKDIR}cropped.png" -resize 32x32 "${WORKDIR}sm_thumb.png"

# turn off debug tracing output
set +o xtrace

OUTPUT=$("${BASE64}" "${WORKDIR}sm_thumb.png")

echo "" > "${WORKDIR}base64.txt"

echo "thumbnail begin 32x32 ${#OUTPUT}" >> "${WORKDIR}base64.txt"
echo "${OUTPUT}" >> "${WORKDIR}base64.txt"
echo "thumbnail end" >> "${WORKDIR}base64.txt"

# Second thumbnail: takes crop and resizes/scales to 400px wide image
if [[ "${TWO_THUMBNAILS}" == "1" ]] ; then
    "${CONVERT}" "${WORKDIR}cropped.png" -resize 400x  "${WORKDIR}bigthumb.png"
    bigthumbdim=$("${IDENTIFY}" -ping -format '%[w]x%[h]' "${WORKDIR}bigthumb.png")
    OUTPUT=$("${BASE64}" "${WORKDIR}bigthumb.png")
    # include image dimensions and length of base64 encode string
    echo "${bigthumbdim} ${#OUTPUT}"
    echo "thumbnail begin ${bigthumbdim} ${#OUTPUT}" >> "${WORKDIR}base64.txt"
    echo "${OUTPUT}" >> "${WORKDIR}base64.txt"
    echo "thumbnail end" >> "${WORKDIR}base64.txt"
fi

# turn on debug tracing output
set -o xtrace

# these need to be embedded as gcode comments
sed -i '' 's/^/; /' "${WORKDIR}base64.txt"

# prepend the thumbnails to original gcode file
cp -f "$GCODE" "$GCODE".orig
cat "${WORKDIR}base64.txt" "$GCODE" > "${WORKDIR}newFile.gcode"
mv "${WORKDIR}newFile.gcode" "$GCODE"
