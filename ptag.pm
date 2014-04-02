package ptag;

use Moose;
use MP3::Tag;
use Data::Dumper;
use constant PTAG_VERSION => 'PerlTAG 1.0 (beta)';
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
		my $directory     = shift || die("Directory is mandatory\n");
		my $search_string = shift || undef;

		$this->set_directory( $directory );
		$this->set_search_string( $search_string );

		$this->prepare_search_string();
		$this->read_files();
	
		print PTAG_VERSION ."\n";
		return $this->search_and_tag();
}


##  method      : prepare_search_string
##  author      : Felix
##  description : When the search string is not present uses the directory name as a search string
sub prepare_search_string
{
		my $this = shift;

		my $directory     = $this->get_directory();
		my $search_string = $this->get_search_string();

		if( length($directory) < 5 && not defined $search_string )
		{
				print "Sorry Adele and your '19' & '21' discs, but...\n";
				die("It's impossible to get anything without a search string and less than a 5 bytes long directory name!\n");
		}
		elsif( not defined $search_string )
		{
				my @cols = split /\//, $directory;
				$this->set_search_string( $cols[$#cols] );
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
		for my $webservice ( @{$this->get_webservices} )
		{
				print "Using ".$webservice->get_name()."\n";
				print "Looking for albums...\n";
				if( my $result = $webservice->find($this->get_search_string(), $this->get_files) )
				{
						print "Tagging disc...\n";
						my $tracks = $result->{album}->get_tracks();
						my $files  = $this->get_files();

						for( my $i=0; $i<=$#{$files}; ++$i )
						{
								$this->tag( $files->[$i], $result->{album}, $result->{file_track_map}{$i} );
						}
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
		my $amazon = ptag::amazon_com->new();

		return [ $amazon ];
}

1;
