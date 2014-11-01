package ptag::amazon_com;

use Moose;
use ptag::album;
use LWP::Simple;
use constant SUBSTRING_LENGTH => 5;
use constant WEBSERVICE_NAME => 'Amazon.com v1.0';
use constant DEBUG => 0; # 1 => just print | 2 => print + html from the LWP::Simple

has 'album'    => ( is => 'rw', reader => 'get_album',    writer => 'set_album' );

## Method      : get_name
## Author      : Felix
## Description : Returns the webservice string name
sub get_name
{
		my $this = shift;
		return WEBSERVICE_NAME;
}

## Method      : find
## Author      : Felix
## Description : Try to find a disc matching the given files and search string
sub find
{
		my $this = shift;
		my $search_string = shift || die('Search string is mandatory');
		my $files         = shift || die('Files are mandatory');

		print "Using: '$search_string' as search pattern!\n";

		my $album = 0;
		my $first_album_found = 0;
		for my $album_url ( @{$this->query($search_string)} )
		{
				print "Url: $album_url\n" if DEBUG;
				$album = $this->construct_album_from_url( $album_url );
				$first_album_found = $album_url if not $first_album_found;
				if( my $file_track_map = $this->compare($files, $album) )
				{
						print "Tracks & Disc FOUND!!\n";
						$this->set_album( $album );
						return { album => $album, file_track_map => $file_track_map };
				}
				else
				{
						print ".\n";
				}
		}

 		if( $first_album_found )
		{
				print "Disc FOUND! [without tracks]\n";
				return { album => $first_album_found, file_track_map => {} };
		}

		print "*SORRY* but the disc couldn't be found!\n";
		return 0;
}


## Method      : query
## Author      : Felix
## Description : Query Amazon.com for a list of album URLs
sub query
{
		my $this = shift;
		my $search_string = shift || die("Can't search without a search string\n");
		my $arrayref_of_album_urls = [];

		$search_string =~ s/ /+/g;
		my $content = get("http://www.amazon.com/s/ref=nb_sb_noss?field-keywords=$search_string");
		if( DEBUG > 1 )
		{
				open( A, ">result_content.html" );
				print A $content;
				close( A );
		}
		my @html_lines = split /\n/, $content;
		for my $line ( @html_lines )
		{
		    $line =~ s/<a/\n<a/g;
		    $line =~ s/<span/\n<span/g;

		    # Pre-2014 way
		    if( $line =~ /<div class="productTitle"><a href="(.+?)">\s*([^<]+)\s*<\/a>/i )
		    {
			push @{$arrayref_of_album_urls}, $1;
		    }

		    ## End-2014
		    if( $line =~ /<a class=".+?" title=".+?" href="(.+?)"><h2 class=".+?">(.+?)<\/h2><\/a>/ )
		    {
			push @{$arrayref_of_album_urls}, $1;
		    }

		}
		return $arrayref_of_album_urls;
}


## Method      : construct_album_from_url
## Author      : Felix
## Description : Returns an album given a URL
sub construct_album_from_url
{
		my $this = shift;
		my $album_url = shift || die("Can't construct an album given an empty URL!\n");
		my $content = get( $album_url );
		my @html_lines = split /\n/, $content;

		if( DEBUG > 1 )
		{
				open( A, ">disc_content.html" );
				print A $content;
				close( A );
		}

		my $album = ptag::album->new();
		my $track_parser_state = 1;
		my $saved_track_number = 0;
		for my $line ( @html_lines )
		{
				##  Album Name
				## ----------------------
				if( $line =~ /<span id="btAsinTitle"\s*>(.+?)</i )
				{
						$album->set_name( $1 );
						print "Album: $1\n" if DEBUG;
				}


				##  Artist
				## ----------------------
				if( 
						!$album->get_artist()
						&& 
						(
						 $line =~ /<td class="titleCol"><a href=".+?">(.+?)<\/a><\/td>/i
						 or $line =~ /<a href=".+?">(.+?)<\/a><span class="byLinePipe">/i 
						 or $line =~ /<a href=".+?artist=.+?">(.+?)<\/a>\s*<span class="byLinePipe">\(Artist\)/i
						)
						)
				{
						$album->set_artist( $1 );
						print "Artist: $1\n" if DEBUG;
				}


				##  Cover
				## ----------------------
				if( $line =~ /\{"initial":\[\{".+?":"(.+?)"/ )
				{
						$album->set_cover( get( $1 ) );
						print "Cover: $1\n" if DEBUG;
				}


				##  Tracks
				## ----------------------
				$line =~ s/&nbsp;/ /g;
				if( $line =~ /<td class="titleCol">\s*(.+?)\s*\.\s*<a href=".+?">\s*(.+?)\s*<\/a><\/td>/i )
				{
						my $track = ptag::track->new();
						$track->set_number( $1 );
						$track->set_name( $2 );
						$album->add_track( $track );
						print "Track: $1. $2\n" if DEBUG;
				}

				if( $track_parser_state == 1 and $line =~ /<div class="a-section track_number">/ )
				{
						$track_parser_state = 2;
				}

				if( $track_parser_state == 2 and $line =~ /^\s*([0-9]+)\s*$/ )
				{
						$saved_track_number = $1;
						$track_parser_state = 3;
				}

				if( $track_parser_state == 4 and $line =~ /^\s*(.+)\s*$/ )
				{
						my $track = ptag::track->new();
						$track->set_number( $saved_track_number );
						$track->set_name( $1 );
						$album->add_track( $track );						
						print "Track: $saved_track_number. $1\n" if DEBUG;
						$track_parser_state = 1;
				}

				if( $track_parser_state == 3 and $line =~ /<a class=".+?" title=".+?" href=".+?">/ )
				{
						$track_parser_state = 4;
				}

				##  Year
				## ----------------------
				if( $line =~ /<li><b>.+?Date:<\/b>\s*([0-9]+)<\/li>/i ) # Format => Release Date: Year
				{
						print "Year: $1\n" if DEBUG;
						$album->set_year( $1 );
				}
				if( $line =~ /<li><b>audio cd<\/b>\s*\([a-z]+ [0-9]+, ([0-9]+)\)<\/li>/i )  # Format => Month 1st, year
				{
						print "Year: $1\n" if DEBUG;
						$album->set_year( $1 );
				}
		}
    
    unless( $album->get_cover() )
    {
      ## Read cover from directory if available
      if( -e './folder.jpg' )
      {
        open(COVER, './folder.jpg');
        binmode (COVER);
        my $cover;
        read (COVER, $cover, 1024*1024); # file can't be bigger than 1mb :-), sorry!
        close(COVER);
        $album->set_cover($cover);
        print STDERR "**WARNING**  Cover was picked up from ./folder.jpg!\n";
      }
      else
      {
        print STDERR "**WARNING**  No cover available and no folder.jpg found in this directory!\n";
      }
    }
		return $album;
}


## Method      : Compare
## Author      : Felix
## Description : Returns 1 if the album matches the files, and 0 otherwise
sub compare
{
		my $this  = shift;
		my $files = shift;
		my $album = shift;

		my $found_disc = 1;
		my $compare_map = {};

		for( my $i=0; $i<=$#{$files}; ++$i )
		{
				my $file = $files->[$i];
				my $tracks = $album->get_tracks();
				for( my $j=0; $j<=$#{$tracks}; ++$j )
				{
						my $track = $tracks->[$j]->get_name();
						my $file_normalized  = $this->normalize_string( $file );
						my $track_normalized = $this->normalize_string( $track );
						my $found = 0;

						##  Perfect match
						## ---------------
						if( $file_normalized eq $track_normalized )
						{
								$found = 1;
								$compare_map->{$i} = $j;
								last;
						}

						##  Match without vowels
						## ---------------
						my $file_normalized_without_vowels = $file_normalized;
						my $track_normalized_without_vowels = $track_normalized;
						$file_normalized_without_vowels =~ s/[aeiou]//g;
						$track_normalized_without_vowels =~ s/[aeiou]//g;
						if( $file_normalized_without_vowels eq $track_normalized_without_vowels )
						{
								$found = 1;
								$compare_map->{$i} = $j;
								last;
						}

						##  Match with subtrings
						## ----------------
						if( substr($file_normalized,0,SUBSTRING_LENGTH) eq substr($track_normalized,0,SUBSTRING_LENGTH) )
						{
								$found = 1;
								$compare_map->{$i} = $j;
								last;
						}

						$found_disc &= $found;
				}
		}

		return $found_disc ? $compare_map : 0;
}


## Method      : normalize_string
## Author      : Felix
## Description : Wipes out all but letters from a string
sub normalize_string
{
		my $this   = shift;
		my $string = shift || '';
		$string = lc($string);
		$string =~ s/[^a-z]//g;
		return $string;
}

1;
