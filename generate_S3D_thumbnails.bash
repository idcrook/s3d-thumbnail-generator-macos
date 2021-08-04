#!/bin/bash
#!/bin/bash -x

## macos 3D print thumbnail generator script

## Version 0.1.1
## David Crook

#
# - requires imagemagick (convert)
# - requires getwindowid util -  https://github.com/smokris/GetWindowID
#
#   brew install imagemagick
#   brew install smokris/getwindowid/getwindowid
#

SCREENCAPTURE="/usr/sbin/screencapture"
BASE64="/usr/bin/base64"
GETWINDOWID="/usr/local/bin/GetWindowID"
CONVERT="/usr/local/bin/convert"
IDENTIFY="/usr/local/bin/identify"

INSTALL_DIR=`dirname "$0"`/
#INSTALL_DIR="${HOME}/projects/3dprint/s3d-thumbnail-generator-macos/"

# Gcode file is first argument
GCODE="${1:-sample.gcode}"

WORKDIR="$TMPDIR"
#WORKDIR="$INSTALL_DIR"

RETINA_MODE=1
TWO_THUMBNAILS=1
DEFAULT_APP_WIDTH=1100
DEFAULT_APP_HEIGHT=775

touch "${INSTALL_DIR}running"
# echo $WORKDIR > "${INSTALL_DIR}workdir"
# echo $GCODE > "${INSTALL_DIR}arg1"
# echo "$@" > "${INSTALL_DIR}args"

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

# screencapture can accept a window title, but window ID is all that is needed
if [[ "$winidinfo" =~ \"([^\"]+)\" ]] ; then
    wintitle=${BASH_REMATCH[1]}
else
    wintitle=root
fi

# on retina display the "size" is from 2x bitmap
if [[ $RETINA_MODE == "1" ]] ; then
    imgwidth=$((appwidth * 2))
    imgheight=$((appheight * 2))
else
    imgwidth=$((appwidth * 1))
    imgheight=$((appheight * 1))
fi

"${SCREENCAPTURE}" -x -o -l${winid} "${WORKDIR}window.png"
#     -T <seconds> Take the picture after a delay of <seconds>, default is
#     -x           Do not play sounds.
#     -o           In window capture mode, do not capture the shadow of the window.
#     -l <windowid> Captures the window with windowid.

#########################################################################
# Can tweak values below to match custom Simplify3D window layout
########################################################################

# these two are the size of the image crop
cropw=$(( imgwidth / 2 ))
croph=$(( imgheight / 2 ))

# these are for the upper left corner (origin) to start the crop
cropwinset=$(( imgwidth / 3 + 20))
crophinset=$(( imgwidth / 4 ))

"${CONVERT}" "${WORKDIR}window.png" -crop ${cropw}x${croph}+${cropwinset}+${crophinset} "${WORKDIR}cropped.png"

## Two thumbnails may be creaate

# First thumbnail: a tiny 32x32 px thumbnail
"${CONVERT}" "${WORKDIR}cropped.png" -resize 32x32 "${WORKDIR}sm_thumb.png"

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

set -o xtrace

sed -i '' 's/^/; /' "${WORKDIR}base64.txt"

# prepend the thumbnails to original gcode file
cat "${WORKDIR}base64.txt" "$GCODE" > "${WORKDIR}newFile.gcode"
mv "${WORKDIR}newFile.gcode" "$GCODE"
