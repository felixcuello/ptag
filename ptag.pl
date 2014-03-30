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

my $ptag = ptag->new();
if( $ptag->process_directory($directory, $artist, $album, $year) )
{
		print "Disc was tagged!\n";
}
else
{
		print "Disc could not be found! :-(\n";
}

