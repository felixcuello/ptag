#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
use ptag;

my $directory = '.';
my $artist;
my $year;
my $album;
my $search;

GetOptions
   		(
     "search=s"    => \$search,
		 "directory=s" => \$directory,
		 "artist=s"    => \$artist,
		 "year=i"      => \$year,
		 "album=s"     => \$album,
		);

my $ptag = ptag->new();
if( $ptag->process_directory($search, $directory, $artist, $album, $year) )
{
		print "Disc was tagged!\n";
}
else
{
		print "Disc could not be found! :-(\n";
}

