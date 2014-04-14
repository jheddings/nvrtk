#!/usr/bin/perl -w

use strict;
use DateTime;
use Config::Simple;
use File::Spec;
use File::Copy;
use File::Basename;
use File::Path;

# load configuration params - XXX yaml might be easier for storing camera config
my $cfg = new Config::Simple('capture.cfg');
my $duration = $cfg->param('ClipDuration');
my $viddir = $cfg->param('VideoRootDir');
my $imgdir = $cfg->param('ImageRootDir');
my $tmpdir = $cfg->param('TempDir');
my $namef = $cfg->param('FileNameFormat');
my $vcodec = $cfg->param('VideoCodec');

# some globals we'll use later
my $tstamp = DateTime->now;
my @ffmpeg = split(/\s+/, $cfg->param('ffmpeg'));

#-------------------------------------------------------------------------------
sub deploy {
  my ($source, $dest) = @_;

  #printf("DEPLOY %s => %s\n", $source, $dest);
  mkpath(dirname($dest));
  move($source, $dest);
}

#-------------------------------------------------------------------------------
sub get_image {
  my ($camera, $stream) = @_;

  my $filename = $tstamp->strftime($namef) . '.jpg';
  my $tmpfile = File::Spec->catfile($tmpdir, $filename);
  my $imgfile = File::Spec->catfile($imgdir, $camera, $filename);

  # let ffmpeg do the heavy lifting
  system(@ffmpeg, '-i', $stream, '-vframes', 1, $tmpfile);

  deploy($tmpfile, $imgfile);

  # TODO update current.jpg (symlink?) to new snapshot
}

#-------------------------------------------------------------------------------
sub get_clip {
  my ($camera, $stream) = @_;

  my $filename = $tstamp->strftime($namef) . '.mov';
  my $tmpfile = File::Spec->catfile($tmpdir, $filename);
  my $vidfile = File::Spec->catfile($viddir, $camera, $filename);

  # let ffmpeg do the heavy lifting
  system(@ffmpeg, '-i', $stream, '-t', $duration, '-vcodec', $vcodec, $tmpfile);

  deploy($tmpfile, $vidfile);

  # TODO update current.jpg (symlink?) to new snapshot
}

get_image('front-porch-test', 'rtsp://192.168.0.101/stream1');
get_clip('front-porch-test', 'rtsp://192.168.0.101/stream1');
