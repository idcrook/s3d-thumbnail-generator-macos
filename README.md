# s3d-thumbnail-generator-macos

Creates gcode thumbnails from Simplify3D within macOS environment.

Tested with [Slicer Thumbnails](https://plugins.octoprint.org/plugins/prusaslicerthumbnails/) plugin for OctoPrint.

## Install

1. Install dependencies. Use Homebrew.

    ```shell
    brew install imagemagick
    brew install smokris/getwindowid/getwindowid
    ```

1. Clone this repo somewhere in your macOS home directory.

1. In the included `generate_S3D_thumbnails.bash` script
   - Customize any paths (should most should be fine as is)
   - May have to iterate on the image dimensions and proprotions to match your window preferences.

1. Add to `Additional terminal commands for post processing` in the *Scripts* tab in *Process* settings, e.g.

    ```shell
    /Users/username/projects/3dprint/s3d-thumbnail-generator-macos/generate_S3D_thumbnails.bash "[output_filepath]"
    ```

1. Now when you save the `.gcode` file in **`Simplify3D.app`**, thumbnails get embedded directly.

1. For recent macOS, in *System Preferences* and in the *Security and Privacy* preferences, in the *Privacy* tab, you will have to enable **Accessibility** and **Screen Recording** features for **`Simplify3D.app`**
   - This is so the post-processing script can automatically capture the Simplify3D app window, as this is how the script works.


## Additional Settings



### Use Sliced preview or normal view

In Application **Preferences** in the *Visualization* tab, uncheck

- [ ] "Automatically load preview after slicing"

if you prefer the non-sliced preview version.  The image crop and dimension settings may be unique to the preview type and your macOS desktop setup.

![Visualization - load preview after slicing](load_preview_after_slicing.png)



## SEE ALSO

  - https://plugins.octoprint.org/plugins/prusaslicerthumbnails/

      - https://github.com/boweeble/s3d-thumbnail-generator
      - https://github.com/NotExpectedYet/s3d-thumbnail-generator
