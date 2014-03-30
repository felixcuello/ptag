package ptag;

use Moose;

has 'directory'     => ( is => 'rw', reader => 'get_directory',     writer => 'set_directory' );
has 'files'         => ( is => 'rw', reader => 'get_files',         writer => 'set_files' );
has 'search_string' => ( is => 'rw', reader => 'get_search_string', writer => 'set_search_string' );

sub process_directory
{
		my $this          = shift;
		my $directory     = shift || die("Directory is mandatory\n");
		my $search_string = shift || undef;

		$this->set_directory( $directory );
		$this->set_search_string( $search_string );

		$this->prepare_search_string();
		$this->read_files();

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
				$webservice->find($this->get_search_string(), $this->get_files);

				if( $webservice->found_disc() )
				{
						$webservice->tag( $this->get_directory );
						return 1;
				}
		}

		return 0;
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
