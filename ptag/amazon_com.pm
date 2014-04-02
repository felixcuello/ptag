package ptag::amazon_com;

use Moose;
use ptag::album;
use LWP::Simple;
use constant SUBSTRING_LENGTH => 5;
use constant WEBSERVICE_NAME => 'Amazon.com v1.0';

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
		for my $album_url ( @{$this->query($search_string)} )
		{
				my $album = $this->construct_album_from_url( $album_url );
				if( my $file_track_map = $this->compare($files, $album) )
				{
						print "Disc FOUND!!\n";
						$this->set_album( $album );
						return { album => $album, file_track_map => $file_track_map };
				}
				print ".\n";
		}
		print "Disc not found!\n";
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
		my @html_lines = split /\n/, $content;
		for my $line ( @html_lines )
		{
				if( $line =~ /<div class="productTitle"><a href="(.+?)">\s*([^<]+)\s*<\/a>/i )
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

		my $album = ptag::album->new();
		for my $line ( @html_lines )
		{
				##  Album Name
				## ----------------------
				if( $line =~ /<span id="btAsinTitle"\s*>(.+?)<span/i )
				{
						$album->set_name( $1 );
				}


				##  Artist
				## ----------------------
				if( !$album->get_artist() && $line =~ /<td class="titleCol"><a href=".+?">(.+?)<\/a><\/td>/ )
				{
						$album->set_artist( $1 );
				}


				##  Cover
				## ----------------------
				if( $line =~ /\{"initial":\[\{".+?":"(.+?)"/ )
				{
						$album->set_cover( get( $1 ) );
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
				}


				##  Year
				## ----------------------
				if( $line =~ /<li><b>.+?Date:<\/b>\s*([0-9]+)<\/li>/i )
				{
						$album->set_year( $1 );
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

		my $found = 0;
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
				}
		}

		return $found ? $compare_map : 0;
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
