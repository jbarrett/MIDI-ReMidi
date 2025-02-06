use strict;
use warnings;
package MIDI::libremidi;

use FFI::C;
use FFI::Platypus 2.00;
use FFI::CheckLib 0.25 qw/ find_lib_or_exit /;

our $VERSION = '0.00';

# ABSTRACT: Bindings for libremidi - Realtime MIDI library with MIDI 2.0 support

my $ffi = FFI::Platypus->new(
    api => 2,
    lib => [
        find_lib_or_exit(
            lib   => 'libremidi',
            alien => 'Alien::libremidi',
        )
    ]
);
FFI::C->ffi($ffi);

$ffi->type( 'unsigned char' => 'libremidi_midi1_symbol' );
$ffi->type( 'libremidi_midi1_symbol*' => 'libremidi_midi1_message' );

$ffi->type( uint32_t => 'libremidi_midi2_symbol' );
$ffi->type( 'libremidi_midi2_symbol*' => 'libremidi_midi2_message' );

$ffi->type( int64_t => 'libremidi_timestamp' );

FFI::C->enum( libremidi_api => [
    [ UNSPECIFIED => 0x0 ], [ COREMIDI => 0x1 ],
    qw/
        ALSA_SEQ
        ALSA_RAW
        JACK_MIDI
        WINDOWS_MM
        WINDOWS_UWP
        WEBMIDI
        PIPEWIRE
        KEYBOARD
        NETWORK
    /,
    [ ALSA_RAW_UMP => 0x1000 ],
    qw/
        ALSA_SEQ_UMP
        COREMIDI_UMP
        WINDOWS_MIDI_SERVICES
        KEYBOARD_UMP
        NETWORK_UMP
    /,
    [ DUMMY => 0xFFFF ]
] );

FFI::C->enum( libremidi_timestamp_mode => [ qw/
    NoTimestamp
    Relative
    Absolute
    SystemMonotonic
    AudioFrame
    Custom
/ ] );

FFI::C->enum( _libremidi_configuration_type => [ qw/
    Observer
    Input
    Output
qw/ ] );

package libremidiApiConfiguration {
    FFI::C->struct([
        api => 'libremidi_api',
        configuration_type => '_libremidi_configuration_type',
        data => 'opaque',
    ]);
}


#$ffi->type( 'opaque' => '_libremidi_cb' );
#$ffi->type( 'opaque' => '_libremidi_error_cb' );
$ffi->type( '(opaque,opaque)->void' => '_libremidi_cb' );
$ffi->type( '(opaque,opaque,size_t,opaque)->void' => '_libremidi_error_cb' );

package libremidiCallback {
    FFI::C->struct([
        context => 'opaque',
        callback => 'opaque'
    ]);
    # dereferencing / casting subs here?
}

package libremidiObserverConfiguration {
    FFI::C->struct([
        on_error => 'libremidi_callback_t',
        on_warning => 'libremidi_callback_t',
        input_added => 'libremidi_callback_t',
        input_removed => 'libremidi_callback_t',
        output_added => 'libremidi_callback_t',
        output_removed => 'libremidi_callback_t',
        track_hardware => 'bool',
        track_virtual => 'bool',
        track_any => 'bool',
        notify_in_constructor => 'bool'
    ]);
}

FFI::C->enum( _libremidi_callback_type => [
    [ MIDI1 => 1 << 1 ],
    [ MIDI1_RAW => 1 << 2 ],
    [ MIDI2 => 1 << 3 ],
    [ MIDI2_RAW => 1 << 4 ],
]);

package libremidiUnionPort {
    FFI::C->union([
        in_port => 'opaque',
        out_port => 'opaque',
    ])
}

package libremidiUnionCallback {
    FFI::C->union([
        on_midi1_message => 'libremidi_callback_t',
        on_midi1_raw_data => 'libremidi_callback_t',
        on_midi2_message => 'libremidi_callback_t',
        on_midi2_raw_data => 'libremidi_callback_t',
    ]);
}

package libremidiMidiConfiguration {
    FFI::C->struct([
        version => '_libremidi_callback_type',
        port => 'libremidi_union_port_t',
        callback => 'libremidi_union_callback_t',
        get_timestamp => 'libremidi_callback_t',
        on_error => 'libremidi_callback_t',
        on_warning => 'libremidi_callback_t',
        port_name => 'opaque',
        virtual_port => 'bool',
        ignore_sysex => 'bool',
        ignore_timing => 'bool',
        ignore_sensing => 'bool',
        timestamps => 'libremidi_timestamp_mode'
    ]);
}

my $bindings = {
    # API utilities
    libremidi_get_version => [ [] => 'string' ],
    libremidi_midi1_available_apis => [ [ 'opaque', 'opaque' ] ],
    libremidi_midi2_available_apis => [ [ 'opaque', 'opaque' ] ],
    libremidi_api_identifier => [ [ 'libremidi_api'] => 'string' ],
    libremidi_api_display_name => [ [ 'libremidi_api'] => 'string' ],
    libremidi_get_compiled_api_by_identifier => [ [ 'string' ] => 'libremidi_api' ],

    # Create configurations
    libremidi_midi_api_configuration_init => [ [ 'libremidi_api_configuration_t' ] => 'int' ],
    libremidi_midi_observer_configuration_init => [ [ 'libremidi_observer_configuration_t' ] => 'int' ],
    libremidi_midi_configuration_init => [ [ 'libremidi_midi_configuration_t' ] => 'int' ],

    # Read information about port objects
    libremidi_midi_in_port_clone => [ [ 'opaque', 'opaque*' ] => 'int' ],
    libremidi_midi_in_port_free => [ [ 'opaque' ] => 'int' ],
    libremidi_midi_in_port_name => [ [ 'opaque', 'char*', 'int*' ] => 'int' ],
    libremidi_midi_out_port_clone => [ [ 'opaque', 'opaque*' ] => 'int' ],
    libremidi_midi_out_port_free => [ [ 'opaque' ] => 'int' ],
    libremidi_midi_out_port_name => [ [ 'opaque', 'char*', 'int*' ] => 'int' ],

    # Observer API
    libremidi_midi_observer_new => [ [ 'libremidi_observer_configuration_t', 'libremidi_api_configuration_t', 'opaque' ] => 'int' ],
    libremidi_midi_observer_enumerate_input_ports => [ [ 'opaque', 'opaque', 'opaque' ] => 'int' ],
    libremidi_midi_observer_enumerate_output_ports => [ [ 'opaque', 'opaque', 'opaque' ] => 'int' ],
    libremidi_midi_observer_free => [ [ 'opaque' ] => 'int' ],

    # MIDI input API
    libremidi_midi_in_new => [ [ 'libremidi_midi_configuration_t', 'libremidi_api_configuration_t', 'opaque*' ] => 'int' ],
    libremidi_midi_in_is_connected => [ [ 'opaque' ] => 'int' ],
    libremidi_midi_in_absolute_timestamp => [ [ 'opaque' ] => 'libremidi_timestamp' ],
    libremidi_midi_in_free => [ [ 'opaque' ] => 'int' ],

    # MIDI output API
    libremidi_midi_out_new => [ [ 'libremidi_midi_configuration_t', 'libremidi_api_configuration_t', 'opaque*' ] => 'int' ],
    libremidi_midi_out_is_connected => [ [ 'opaque' ] => 'int' ],
    libremidi_midi_out_send_message => [ [ 'opaque', 'libremidi_midi1_symbol*', 'size_t' ] => 'int' ],
    libremidi_midi_out_send_ump => [ [ 'opaque', 'libremidi_midi2_symbol*', 'size_t' ] => 'int' ],
    libremidi_midi_out_schedule_message => [ [ 'opaque', 'int64_t', 'libremidi_midi1_symbol*', 'size_t' ] => 'int' ],
    libremidi_midi_out_schedule_ump => [ [ 'opaque', 'int64_t', 'libremidi_midi2_symbol*', 'size_t' ] => 'int' ],
    libremidi_midi_out_free => [ [ 'opaque' ] => 'int' ],

};

for my $fn ( keys %{ $bindings } ) {
    $ffi->attach( $fn => @{ $bindings->{ $fn } } );
}

1;
