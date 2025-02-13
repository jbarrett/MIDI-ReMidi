use Feature::Compat::Class;
package MIDI::ReMidi::Port;

class MIDI::ReMidi::Port {
    use strict;
    use warnings;

    use Carp qw/ carp croak /;

    no warnings 'experimental::class';

    field $name :param :reader = sprintf( 'libremidi-perl-%04x', rand(0xFFFF) );
    field $api :param :reader = 'UNSPECIFIED';
    field $version :param :reader = 'MIDI1';
    field $on_error :param :reader = sub { croak( @_ ) };
    field $on_warning :param :reader = sub { carp( @_ ) };
    field $get_timestamp :param :reader = sub {};
    field $virtual_port :param :reader = 0;
    field $timestamp_mode :param :reader = 'NoTimestamp';
}

1;
