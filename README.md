# Insert gcode preview thumbnails for Simplify3D on macOS

**IMPORTANT NOTE**: **_Simplify3D_** **`v5.1`** adds native support for thumbnails in `.gcode`. See [Release Notes](S3D_version_5.1_notes.md).

  - **Recommended**: Use the built-in support starting with version 5.1 instead of this post-processing technique.
  - Earlier versions of _Simplify3D_ should continue to work with this post-precessing step, but it has now been deprecated by the native support.


Tested with [Slicer Thumbnails](https://plugins.octoprint.org/plugins/prusaslicerthumbnails/) plugin for OctoPrint.

Tested on **`Simplify3D.app`** `4.1.2` in macOS Big Sur on both Intel and Apple Silicon, and in  **`Simplify3D.app`** `5.0` in macOS Ventura.

## Install

1. Install dependencies. Use macOS [Homebrew](https://brew.sh/).

    ```shell
    brew install imagemagick
    brew install smokris/getwindowid/getwindowid
    ```

1. Clone this repo somewhere in your macOS home directory.

    ```shell
    mkdir -p ~/projects/3dprint
    cd ~/projects/3dprint
    git clone https://github.com/idcrook/s3d-thumbnail-generator-macos.git s3d-thumbnails
    ```

1. Customize the included `generate_S3D_thumbnails.bash` script

   - Customize any paths (most should be fine as-is)
   - May need to iterate on the cropping image dimensions and proportions to match your window layout and preferences.

1. Add script invocation in Simplify 3D gcode post-processing

    ```shell
    /Users/%%USERNAME%%/projects/3dprint/s3d-thumbnails/generate_S3D_thumbnails.bash "[output_filepath]"
    ```

     - `%%USERNAME%%` in the line above is meant to be replaced with your Mac account username.
     - This is added in `Additional terminal commands for post processing` in the *Scripts* tab in *Process* settings, e.g.

     ![Main window - Edit process settings](img/edit_process_settings.png)
     ![FFF Settings - Show advanced](img/show_advanced.png)
     ![Scripts - additional terminal commands for post processing](img/addl_term_cmds.png)

1. Now when you save the `.gcode` file in **`Simplify3D.app`**, thumbnails get embedded directly.

**IMPORTANT**: For recent macOS, in *System Preferences* in the *Security and Privacy* preferences, in the *Privacy* tab, you will have to enable **Screen Recording** (and possibly **Accessibility**) permissions for **`Simplify3D.app`**

   - This is so the post-processing script can automatically screen capture the Simplify3D app window

 - The preview thumbnail is obtained directly from the Simplify3D application window.


With [Slicer Thumbnails](https://plugins.octoprint.org/plugins/prusaslicerthumbnails/) plugin for Octoprint enabled, the thumbnail can be viewed from web interface.

![OctoPrint - View thumbnail](img/thumbnail_in_octoprint.png)

## Additional Settings

### Use Sliced preview or normal view

The thumbnail is captured from the Simplify3D application window when the sliced .gcode file **is saved**.

If you prefer the non-sliced preview version, in Application *Preferences* in the *Visualization* tab, uncheck

- [ ] "Automatically load preview after slicing"

![Visualization - load preview after slicing](img/load_preview_after_slicing.png)

### Customize crop size and position

The image crop and dimension settings may be unique to the preview type and your macOS desktop setup.

These are adjustable in the script. Look for the in the bash script for the section starting at the line `# Position the crop bounding box`

## Troubleshooting

### Getting list of app windows

There is included an applescript that lists running application windows. It can be run as follows:

```shell
$ osascript window_list.scpt
```

This is from example found at <https://stackoverflow.com/a/59293280>

### Manually run script

With **`Simplify3D.app`** open, the thumbnail embedding script can be run on a "dummy" gcode file to confirm that it has been set up correctly or for iterating on thumbnail crop area.

For example, on my Mac that has `zsh` as my terminal shell (long lines truncated in the `less` output):

```console
$ cd ~/projects/3dprint/s3d-thumbnails
$ echo END >! sample.gcode && ./generate_S3D_thumbnails.bash
400x469 237992
$ less sample.gcode
;
; thumbnail begin 32x32 3012
; iVBORw0KGgoAAAANSUhEUgAAABsAAAAgCAMAAADUt/MJAAABNWlDQ1BpY2MAACiRY2Bg4kksKMhhYW
; thumbnail end
; thumbnail begin 400x469 237992
; iVBORw0KGgoAAAANSUhEUgAAAZAAAAHVCAYAAADfKq0TAAABNWlDQ1BpY2MAACiRY2Bg4kksKMhhYW
; thumbnail end
END
$ open $TMPDIR/bigthumb.png
```

#### Does manual run error saying 'Could not find Simplify3D window'

First, check that the application is open. 😄

If it is, then it is likely a macOS permissions problem.  Run the following command in a terminal with S3D app open:

```
GetWindowID Simplify3D --list
```

It should look something like

```
"(null)" size=0x0 id=651
"Simplify3D (Licensed to xxxx xxxx)" size=1200x828 id=650
```

If all lines are instead like `"(null)"`, **DELETE** the entry in *Screen Recording* in `Privacy & Security` area in macOS *System Preferences/Settings* app.  Then try saving the .gcode file again. A dialog should pop up to prompt for setting the *Screen Recording* system permission for the app.

Once it is grant thusly, app name should now show up properly in the `GetWindowID` list again.


### Enable script tracing

To turn on generic bash command tracing, change the first line of the bash script to include the `-x` option.

```
#!/bin/bash -x
```

## SEE ALSO

  - https://plugins.octoprint.org/plugins/prusaslicerthumbnails/

      - https://github.com/boweeble/s3d-thumbnail-generator
      - https://github.com/NotExpectedYet/s3d-thumbnail-generator
