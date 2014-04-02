package ptag::track;

use Moose;

has 'number' => ( is => 'rw', reader => 'get_number', writer => 'set_number' );
has 'name'   => ( is => 'rw', reader => 'get_name',   writer => 'set_name' );

1;
