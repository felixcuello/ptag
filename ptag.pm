package ptag;

use Moose;
use MP3::Tag;
use Data::Dumper;
use constant PTAG_VERSION => 'PerlTAG 1.0 (beta)';
use constant MINIMUM_SEARCH_STRING_LENGTH => 5;
use constant APIC => "APIC";
use constant TYPE => "jpg";
use constant HEADER => ( chr(0x0) , "image/" . TYPE , chr(0x3), "Cover Image");

has 'directory'     => ( is => 'rw', reader => 'get_directory',     writer => 'set_directory' );
has 'files'         => ( is => 'rw', reader => 'get_files',         writer => 'set_files' );
has 'search_string' => ( is => 'rw', reader => 'get_search_string', writer => 'set_search_string' );


##  method      : process_directory
##  author      : Felix
##  description : Main program logic
sub process_directory
{
		my $this          = shift;
		my $search_string = shift || die("Search string is mandatory\n");
		my $directory     = shift || die("Directory is mandatory\n");
		my $artist        = shift;
		my $album_name    = shift;
		my $year          = shift;

		$this->set_directory( $directory );
		$this->prepare_search_string($search_string, $directory);
		$this->read_files();
	
		print PTAG_VERSION ."\n";
		return $this->search_and_tag($artist, $album_name, $year);
}


##  method      : prepare_search_string
##  author      : Felix
##  description : When the search string is not present uses the directory name as a search string
sub prepare_search_string
{
		my $this = shift;
		my $search_string = shift;
		my $directory = shift;

		if( length($search_string) < MINIMUM_SEARCH_STRING_LENGTH )
		{
				my @cols = split /\//, $directory;
				$search_string = $cols[$#cols];

				if( length($search_string) < MINIMUM_SEARCH_STRING_LENGTH )
				{
						print "Sorry Adele and your '19' & '21' discs, but...\n";
						die("It's impossible to get anything without a search string and less than a 5 bytes long directory name!\n");
				}
		}
		else
		{
				$this->set_search_string( $search_string );
		}
}


##  method      : read_files
##  author      : Felix
##  description : Read mp3 files form the given directory
sub read_files
{
		my $this = shift;
		opendir( DIR, $this->get_directory() ) || die("Can't open $this->{directory}\n");
		my $files;
		while( my $file = readdir(DIR) )
		{
				if( $file =~ /^\s*[0-9]*[^a-z]*(.+?)\.mp3\s*$/i )
				{
						push @$files, $file;
				}
		}
		closedir( DIR );
		$this->set_files( $files );
}



##  method      : search_and_tag
##  author      : Felix
##  description : Search a disc and tags the directory
sub search_and_tag
{
		my $this = shift;
		my $artist        = shift || undef;
		my $album_name    = shift || undef;
		my $year          = shift || undef;

		for my $webservice ( @{$this->get_webservices} )
		{
				print "Using ".$webservice->get_name()."\n";
				print "Looking for albums...\n";
				if( my $result = $webservice->find($this->get_search_string(), $this->get_files) )
				{
						print "Tagging disc...\n";

						$result->{album}->set_artist($artist) if( defined $artist );
						$result->{album}->set_name($album_name) if( defined $album_name );
						$result->{album}->set_year($year) if( defined $year );

						my $tracks = $result->{album}->get_tracks();
						my $files  = $this->get_files();

						##  This happens when the disc has been found, but it has no tracks
						## --------------------------
						if( not exists $result->{file_track_map}{0} )
						{
								##  Add tracks using file name information + album information
								## ---------------------------
								for( my $i=0; $i<=$#{$files}; ++$i )
								{
										my $track = ptag::track->new();
										$track->set_number( $i+1 );

										my $track_name = $files->[$i];
										my $track_number = $files->[$i];

										$track_number =~ s/\s*([0-9]+)/$1/;
										$track_name =~ s/[0-9]*\s*[^a-z]?\s*(.+)\.mp3\s*$/$1/i;
										
										my @words = split /\s/, $track_name;
										for my $word ( @words )
										{
												$word = ucfirst( $word );
										}

										$track->set_name( (join ' ', @words) );
										$result->{album}->add_track( $track );
										$result->{file_track_map}{$i} = $i;
								}
						}

						for( my $i=0; $i<=$#{$files}; ++$i )
						{
								$this->tag( $files->[$i], $result->{album}, $result->{file_track_map}{$i} );
						}

						rename( $this->get_directory(), sprintf("%s (%d)", $result->{album}->get_name(), $result->{album}->get_year()) );
						return 1;
				}
		}

		return 0;
}



##  method      : tag
##  author      : Felix
##  Description : Tags a file given a filename, $album and track position
sub tag
{
		my $this = shift;
		my $filename     = shift || die("filename is mandatory\n");
		my $album        = shift || die("album is mandatory\n");
		my $track_number = shift;

		my $directory    = $this->get_directory();
		
		$filename = "${directory}/${filename}";

		$this->clean_tags( $filename );
		$this->write_tags( $filename, $album, $track_number );
		if( my $cover = $album->get_cover() )
		{
				$this->write_cover( $filename, $cover );	
				open( COVER, ">$directory/folder.jpg" );
				print COVER $cover;
				close( COVER );
		}

		my $track = $album->get_track($track_number);
		my $new_name = sprintf("%s/%02d. %s.mp3", $directory, $track_number+1, $track->get_name());
		rename( $filename, $new_name );
}



##  method      : write_cover
##  author      : Felix
##  Description : Adds cover image to the file
sub write_cover
{
		my $this = shift;
		my $filename = shift;
		my $cover    = shift;

		MP3::Tag->config("write_v24" => 1);
		my $mp3 = MP3::Tag->new( $filename );

		my $id3;
		if( exists $mp3->{ID3v2} )
    {   
        $id3 = $mp3->{ID3v2};
    }
    else
    {   
        $id3 = $mp3->new_tag('ID3v2');
    }
		
		my $frames = $id3->supported_frames();
    if( not exists $frames->{APIC} )
    {   
        die("Error " . __LINE__ . " :-(\n");
    }

		my $frameids = $id3->get_frame_ids();
		if( exists $frameids->{APIC})
		{
				$id3->change_frame( APIC, HEADER, $cover );
		}
		else
		{   
				$id3->add_frame(APIC, HEADER, $cover );
		}

		$id3->write_tag();
    $mp3->update_tags();
    $mp3->close();
}



##  method      : write_tags
##  author      : Felix
##  Description : Write the tags to the file
sub write_tags
{
		my $this = shift;
		my $filename = shift;
		my $album = shift;
		my $track_number = shift;

		my $track = $album->get_track($track_number);
 		my $mp3  = MP3::Tag->new( $filename );

		$mp3->update_tags(
				{
						title   => $track->get_name(),
						album   => $album->get_name(),
						artist  => $album->get_artist(),
						year    => $album->get_year(),
						genre   => undef,
						comment => PTAG_VERSION,
				}
				);
}


##  method      : clean_tags
##  author      : Felix
##  Description : Clean tags from file
sub clean_tags
{
		my $this = shift;
		my $filename = shift;
		
		my $mp3 = MP3::Tag->new( $filename );
		$mp3->get_tags();
		if ( exists $mp3->{ID3v2} )
		{
        my $id3v2         = $mp3->{ID3v2};
        my $frame_ids_hash = $id3v2->get_frame_ids();
				for my $frame ( keys %$frame_ids_hash )
				{
						$id3v2->remove_frame($frame);
						$id3v2->write_tag();
				}
		}
		$mp3->{ID3v1}->remove_tag if exists $mp3->{ID3v1};
		$mp3->{ID3v2}->remove_tag if exists $mp3->{ID3v2};
		$mp3->update_tags();
		$mp3->close();
}


##  method      : get_webservices
##  author      : Felix
##  description : Returns an array of webservices (more webservices can be added at an time)
sub get_webservices
{
		my $this = shift;

		use ptag::amazon_com;
		use ptag::amazon_co_uk;
		my $amazon_com = ptag::amazon_com->new();
		my $amazon_co_uk = ptag::amazon_co_uk->new();

		return [ $amazon_com, $amazon_co_uk ];
}

1;
