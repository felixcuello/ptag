#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
use ptag;

my $directory = '.';
my $artist;
my $year;
my $album;

GetOptions
		(
		 "directory=s" => \$directory,
		 "artist=s"    => \$artist,
		 "year=i"      => \$year,
		 "album=s"     => \$album,
		);

ptag::process
		(
		 $directory,
		 $artist,
		 $album,
		 $year
		);

