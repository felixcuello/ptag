package ptag::album;

use Moose;
use ptag::track;

has 'tracks' => ( is => 'rw' );
has 'artist' => ( is => 'rw', reader => 'get_artist', writer => 'set_artist' );
has 'year'   => ( is => 'rw', reader => 'get_year',   writer => 'set_year' );
has 'name'   => ( is => 'rw', reader => 'get_name',   writer => 'set_name' );
has 'cover'  => ( is => 'rw', reader => 'get_cover',  writer => 'set_cover' );


## Method      : add_track
## Author      : Felix                                                                                                                                                                                     
## Description : Add one track to the album
sub add_track
{
		my $this = shift;
		my $track = shift || die("A track is mandatory!\n");
		push @{$this->{tracks}}, $track;
}

## Method      : get_tracks
## Author      : Felix                                                                                                                                                                                     
## Description : Return all tracks
sub get_tracks
{
		my $this = shift;
		return $this->{tracks};
}


## Method      : get_track                                                                                                                                                                                 
## Author      : Felix                                                                                                                                                                                     
## Description : Return the n-track of the disc (0 is the first one)                                                                                                                                      
sub get_track
{
    my $this = shift;
    my $i = shift;
    my $tracks = $this->get_tracks();
    return $tracks->[$i];
}



1;
