#!/usr/bin/perl -w

use strict;
use Config::General;
use Data::Dumper;
use DateTime;
use File::Spec;
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
sub camconfig {
  my $camera = shift;
  my (%params) = @_;

  foreach (keys %params) {
    ${$params{$_}} = $config{Camera}{$camera}{$_} || $config{$_};
  }
}

#-------------------------------------------------------------------------------
sub tempfile {
  use File::Temp;

  my (undef, $tmpfile) = File::Temp::tempfile(DIR => $config{TempDir}, @_);

  return $tmpfile;
}

#-------------------------------------------------------------------------------
sub deploy {
  use File::Basename;
  use File::Copy;
  use File::Path;

  my ($source, $dest) = @_;
  #printf("DEPLOY %s => %s\n", $source, $dest);

  mkpath(dirname($dest));
  move($source, $dest);
}

#-------------------------------------------------------------------------------
sub download {
  use LWP::Simple;

  my ($url, $file) = @_;
  #printf("DOWNLOAD %s => %s\n", $url, $file);

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

  my ($namef, $imgdir, $imgurl, $stream);

  camconfig($camera,
    'FileNameFormat' => \$namef,
    'ImageURL' => \$imgurl,
    'StreamURL' => \$stream,
    'ImageRootDir' => \$imgdir
  );

  my $filename = $tstamp->strftime($namef) . '.jpg';
  my $imgfile = File::Spec->catfile($imgdir, $camera, $filename);
  my $tmpfile = tempfile(SUFFIX => '.jpg');

  if ($imgurl) {
    download($imgurl, $tmpfile);
  } else {
    ffmpeg('-i', $stream, '-vframes', 1, $tmpfile);
  }

  deploy($tmpfile, $imgfile);

  # TODO update current.jpg (symlink?) to new snapshot
}

#-------------------------------------------------------------------------------
sub do_clip {
  my ($camera) = @_;

  my ($namef, $type, $viddir, $stream, $length, $acodec, $vcodec);

  camconfig($camera,
    'FileNameFormat' => \$namef,
    'ClipFileType' => \$type,
    'ClipDuration' => \$length,
    'ClipAudioCodec' => \$acodec,
    'ClipVideoCodec' => \$vcodec,
    'StreamURL' => \$stream,
    'VideoRootDir' => \$viddir
  );

  my $suffix = ".$type";
  my $filename = $tstamp->strftime($namef) . $suffix;
  my $vidfile = File::Spec->catfile($viddir, $camera, $filename);
  my $tmpfile = tempfile(SUFFIX => $suffix);

  # let ffmpeg do the heavy lifting
  ffmpeg('-t', $length, '-i', $stream,
    '-vcodec', $vcodec, '-acodec', $acodec,
    $tmpfile
  );

  deploy($tmpfile, $vidfile);
}

#-------------------------------------------------------------------------------
sub do_prune {
  use File::Find;

  my ($camera) = @_;

  my ($imgdir, $viddir, $days);

  camconfig($camera,
    'ImageRootDir' => \$imgdir,
    'VideoRootDir' => \$viddir,
    'RetentionPeriod' => \$days
  );

  my @paths = ( );

  my $imgpath = File::Spec->catfile($imgdir, $camera);
  push(@paths, $imgpath) if -d $imgpath;

  my $vidpath = File::Spec->catfile($viddir, $camera);
  push(@paths, $vidpath) if -d $vidpath;

  find(sub { unlink if -f && -M > $days; }, @paths);
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
  RetentionPeriod => '30',
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

  do_prune($camera) if $do_prune;
}

