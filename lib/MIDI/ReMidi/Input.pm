use Feature::Compat::Class;
package MIDI::ReMidi::Input;

class MIDI::ReMidi::Input :isa( MIDI::ReMidi::Port ) {
    use strict;
    use warnings;

    use MIDI::ReMidi ':all';

    no warnings 'experimental::class';

    field $callback :param;
    field $ignore_sysex :param = 1;
    field $ignore_timing :param = 1;
    field $ignore_sensing :param = 1;
    field $api_config;
    field $port_config;
    field $port;
    field $handle;

    ADJUST {
        $api_config = libremidiApiConfiguration->new({
            api => $self->api,
            configuration_type => 'Input',
        });

        $port_config = libremidiMidiConfiguration->new({
            version => $self->version,
            port => \$port,
            callback => $callback,
            on_error => $self->on_error,
            on_warning => $self->on_warning,
            port_name => $self->name,
            virtual_port => $self->virtual_port,
            ignore_sysex => $ignore_sysex,
            ignore_timing => $ignore_timing,
            ignore_sensing => $ignore_sensing,
        });

        my $ret = libremidi_midi_in_new( $port_config, $api_config, \$handle );
    }
}

1;
