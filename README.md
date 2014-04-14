nvrtk
=====

A very basic NVR toolkit for recording IP video cameras at home.  This is not intended to
function like standard video surveillance application by providing search & playback
capability.  Instead, this toolkit simply captures clips & stills from cameras defined in
the configuration.  In truth, it is basically a wrapper around ffmpeg with some utilities
for processing config files in a particular way.

This toolkit is designed to work with the system scheduler (e.g. cron) to launch tasks at
specific intervals.  For example, to record a one-hour clip from your cameras, launch
`nvrtk.pl --clip` every hour in your scheduler.  Similarly to remove old files, simply
call `nvrtk.pl --prune` at some regular frequency.

Usage
=====

    usage: nvrtk.pl [<options>] [camera1 [camera2 [...]]]

    where options include:
      --conf <file> : specify config file (default: nvrtk.cfg)
      --snap        : get current snapshot from camera
      --clip        : record next clip from camera
      --prune       : prune old files according to config
      --help        : display help and exit

When invoking nvrtk, simply pass the command you would like to accomplish and the cameras
you want to act on.  If no cameras are specified on the command line, nvrtk will assume all
cameras in the config file.

clip
----

This will create a video clip from the camera based on the configuration.

snap
----

This will create a still image from the camera.

prune
-----

This will remove old files based on the defined retention settings in the config file.

Configuration
=============

Configuration is a bit tricky...  Need to explain it more here.  In general, it is an
Apache-style config file.  See the included sample for a quick start.

Global Options
--------------

Global options are not in a section.  They establish a baseline for how to treat each
device.

* ClipDuration - Specifies the length of time to capture from a stream (default: 1 hour)
* ClipVideoCodec - The ffmpeg video codec to use when encoding a clip (default: copy).
* ClipAudioCodec - The ffmpeg audio codec to use when encoding a clip (default: copy).
* ClipFileType - The file type for saving video clips (default: mov).
* FileNameFormat - The name format used to save files to the NVR storage (default: %Y%m%d%H%M%S).
* ImageRootDir - The base path for storing images (default: current directory).
* VideoRootDir - The base path for storing videos (default: current directory).
* TempDir - A location for storing temporary files (default: system defined).

Camera Section
--------------

Camera sections instruct nvrtk how to reach network devices for capturing data.

    <Camera my-camera-name>
      ImageURL "http://camera.addr/path/to/snapshot"
      StreamURL "rtsp://camera.addr/path/to/live/stream"
    </Camera my-camera-name>

Global options my be defined in Camera sections, thus overriding configuration for a
specific device.

External Tools
--------------

The ExternalTools section changes the way external commands are invoked by nvrtk.  These
should be modified carefully, as incorrect usage will result in unexpected behavior.

    <ExternalTools>
      ffmpeg "ffmpeg -y -hide_banner -loglevel fatal"
    </ExternalTools>
