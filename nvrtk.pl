#!/usr/bin/perl -w

use strict;
use Config::General;
use Data::Dumper;
use DateTime;
use File::Spec;
use File::Copy;
use File::Basename;
use File::Path;
use Getopt::Long;

# some globals we'll use later
my %config;
my $tstamp = DateTime->now;

#-------------------------------------------------------------------------------
sub usage {
  print STDERR << "EOF";
usage: nvrtk.pl [<options>] [camera1 [camera2 [...]]]

where options include:
  --conf <file> : specify config file (default: nvrtk.cfg)
  --snap        : get current snapshot from camera
  --clip        : record next clip from camera
  --prune       : prune old files according to config
  --help        : display this help and exit
EOF

  exit (shift || 0);
}

#-------------------------------------------------------------------------------
sub deploy {
  my ($source, $dest) = @_;

  mkpath(dirname($dest));
  move($source, $dest);
}

#-------------------------------------------------------------------------------
sub camparam {
  my ($camera, $param) = @_;

  return $config{Camera}{$camera}{$param} || $config{$param};
}

#-------------------------------------------------------------------------------
sub download {
  use LWP::Simple;
  my ($url, $file) = @_;

  my $status = getstore($url, $file);

  if (! is_success($status)) {
    warn "error downloading file: $status - $!";
  }
}

#-------------------------------------------------------------------------------
sub ffmpeg {
  my $ffmpeg = $config{ExternalTools}{ffmpeg} || 'ffmpeg -y';

  system(split(/\s+/, $ffmpeg), @_);
}

#-------------------------------------------------------------------------------
sub do_snap {
  my ($camera) = @_;

  my $namef = camparam($camera, 'FileNameFormat');
  my $filename = $tstamp->strftime($namef) . '.jpg';

  my $imgdir = camparam($camera, 'ImageRootDir');
  my $imgfile = File::Spec->catfile($imgdir, $camera, $filename);

  my $tmpdir = camparam($camera, 'TempDir');
  my $tmpfile = File::Spec->catfile($tmpdir, $filename);

  my $imgurl = camparam($camera, 'ImageURL');

  if ($imgurl) {
    download($imgurl, $tmpfile);

  } else {
    my $stream = camparam($camera, 'StreamURL');
    ffmpeg('-i', $stream, '-vframes', 1, $tmpfile);
  }

  deploy($tmpfile, $imgfile);

  # TODO update current.jpg (symlink?) to new snapshot
}

#-------------------------------------------------------------------------------
sub do_clip {
  my ($camera) = @_;

  my $namef = camparam($camera, 'FileNameFormat');
  my $suffix = camparam($camera, 'ClipFileType');
  my $filename = $tstamp->strftime($namef) . '.' . $suffix;

  my $viddir = camparam($camera, 'VideoRootDir');
  my $vidfile = File::Spec->catfile($viddir, $camera, $filename);

  my $tmpdir = camparam($camera, 'TempDir');
  my $tmpfile = File::Spec->catfile($tmpdir, $filename);

  my $stream = camparam($camera, 'StreamURL');
  my $acodec = camparam($camera, 'ClipVideoCodec');
  my $vcodec = camparam($camera, 'ClipAudioCodec');
  my $duration = camparam($camera, 'ClipDuration');

  # let ffmpeg do the heavy lifting
  ffmpeg('-t', $duration, '-i', $stream,
    '-vcodec', $vcodec, '-acodec', $acodec,
    $tmpfile
  );

  deploy($tmpfile, $vidfile);
}

#-------------------------------------------------------------------------------
sub do_prune {
  my ($camera) = @_;
}

#===============================================================================
# MAIN APPLICATION ENTRY

my $cfg_file = 'nvrtk.cfg';
my $do_snap = 0;
my $do_clip = 0;
my $do_prune = 0;

GetOptions(
  'conf=s' => \$cfg_file,
  'snap' => \$do_snap,
  'clip' => \$do_clip,
  'prune' => \$do_prune,
  'help' => sub { usage(0); }
) || usage(1);

my %default_config = (
  ClipDuration => '01:00:00',
  ClipVideoCodec => 'copy',
  ClipAudioCodec => 'copy',
  ClipFileType => 'mov',
  FileNameFormat => '%Y%m%d%H%M%S',
  TempDir => File::Spec->tmpdir()
);

%config = Config::General->new(
  -ConfigFile => $cfg_file,
  -MergeDuplicateOptions => 1,
  -UseApacheInclude => 1,
  -IncludeDirectories => 1,
  -IncludeGlob => 1,
  -IncludeRelative => 1,
  -DefaultConfig => \%default_config
)->getall;
#print Dumper(\%config);

my @cameras = ( );
if (scalar(@ARGV)) {
  push(@cameras, @ARGV);
} else {
  push(@cameras, keys %{$config{Camera}});
}

foreach my $camera (@cameras) {
  die "invalid camera: $camera" unless $config{Camera}{$camera};

  do_snap($camera) if $do_snap;
  do_clip($camera) if $do_clip;

  #do_prune($camera) if $do_prune;
}

