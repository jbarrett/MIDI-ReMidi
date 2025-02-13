use strict;
use warnings;
package MIDI::ReMidi;
use base qw/ Exporter /;

use FFI::C;
use FFI::Platypus 2.00;
use FFI::CheckLib 0.25 qw/ find_lib_or_exit /;
use FFI::Platypus::Buffer qw/ buffer_to_scalar /;

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

$ffi->type( '(opaque,int64_t,opaque,size_t)->void' => '_libremidi_midi_cb' );
$ffi->type( '(opaque,opaque)->void' => '_libremidi_observer_cb' );
$ffi->type( '(opaque,opaque,size_t,opaque)->void' => '_libremidi_error_cb' );
$ffi->type( '(opaque,int64_t)->void' => '_libremidi_timestamp_cb' );

package libremidiCallback {
    FFI::C->struct([
        context => 'opaque',
        callback => 'opaque'
    ]);
    sub err_cb { shift->callback( $ffi->cast( _libremidi_error_cb => 'opaque', @_ ) ) }
    sub midi_cb { shift->callback( $ffi->cast( _libremidi_midi_cb => 'opaque', @_ ) ) }
    sub obs_cb { shift->callback( $ffi->cast( _libremidi_observer_cb => 'opaque', @_ ) ) }
    sub ts_cb { shift->callback( $ffi->cast( _libremidi_timestamp_cb => 'opaque', @_ ) ) }
}

# Use this if libremidiCallback doesn't work
package ReMidiCallback {
    use FFI::Platypus::Record;
    record_layout_1(
        'opaque' => 'context',
        'opaque' => 'callback',
    );
}

package libremidiObserverConfiguration {
    FFI::C->struct([
        _on_error => 'libremidi_callback_t',
        _on_warning => 'libremidi_callback_t',
        _input_added => 'libremidi_callback_t',
        _input_removed => 'libremidi_callback_t',
        _output_added => 'libremidi_callback_t',
        _output_removed => 'libremidi_callback_t',
        track_hardware => 'bool',
        track_virtual => 'bool',
        track_any => 'bool',
        notify_in_constructor => 'bool'
    ]);
    sub on_error { shift->_on_error( _wrap_err_cb( @_ ) ) }
    sub on_warning { shift->_on_warning( _wrap_err_cb( @_ ) ) }
    sub input_added { shift->_input_added( _wrap_obs_cb( @_ ) ) }
    sub input_removed { shift->_input_removed( _wrap_obs_cb( @_ ) ) }
    sub output_added { shift->_output_added( _wrap_obs_cb( @_ ) ) }
    sub output_removed { shift->_output_removed( _wrap_obs_cb( @_ ) ) }
}

FFI::C->enum( libremidi_midi_version => [
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
        version => 'libremidi_midi_version',
        port => 'opaque',
        _callback => 'libremidi_callback_t',
        _get_timestamp => 'libremidi_callback_t',
        _on_error => 'libremidi_callback_t',
        _on_warning => 'libremidi_callback_t',
        _port_name => 'opaque',
        virtual_port => 'bool',
        ignore_sysex => 'bool',
        ignore_timing => 'bool',
        ignore_sensing => 'bool',
        timestamps => 'libremidi_timestamp_mode'
    ]);
    sub in_port { shift->port( @_ ) }
    sub out_port { shift->port( @_ ) }
    sub callback { shift->_callback( MIDI::ReMidi::_wrap_midi_cb( @_ ) ) }
    *on_midi1_message = \&callback;
    *on_midi1_raw_data = \&callback;
    *on_midi2_message = \&callback;
    *on_midi2_raw_data = \&callback;
    sub get_timestamp { shift->_get_timestamp( MIDI::ReMidi::_wrap_ts_cb( @_ ) ) }
    sub on_error { shift->_on_error( MIDI::ReMidi::_wrap_err_cb( @_ ) ) }
    sub on_warning { shift->_on_warning( MIDI::ReMidi::_wrap_err_cb( @_ ) ) }
    sub port_name {
        my ( $self, $name ) = @_;
        return $ffi->cast( 'opaque', 'string', $self->_port_nam )
            unless defined $name;
        $self->_port_name( $ffi->cast( 'string', 'opaque', $name ) );
    }
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

sub _ffi { $ffi }

sub _wrap_cb {
    my ( $key, $callback ) = @_;
    {
        context => undef,
        $key => $ffi->closure( $callback )
    };
}

sub _wrap_midi_cb {
    my ( $callback ) = @_;
    my $cb = sub {
        shift;
        my ( $ts, $sym, $len ) = @_;
        my $symbol = buffer_to_scalar( $sym, $len );
        $callback->( $ts, $symbol );
    };
    _wrap_cb( midi_cb => $cb );
}

sub _wrap_err_cb {
    my ( $callback, $key ) = @_;
    my $cb = sub {
        shift;
        my ( $err, $len, $loc ) = @_;
        my $error = buffer_to_scalar( $err, $len );
        $callback->( $error, $loc );
    };
    _wrap_cb( err_cb => $cb );
}

sub _wrap_obs_cb {
    my ( $callback, $key ) = @_;
    my $cb = sub {
        shift;
        $callback->( @_ );
    };
    _wrap_cb( obs_cb => $cb );
}

sub _wrap_ts_cb {
    my ( $callback, $key ) = @_;
    my $cb = sub {
        shift;
        $callback->( @_ );
    };
    _wrap_cb( ts_cb => $cb );
}

for my $fn ( keys %{ $bindings } ) {
    $ffi->attach( $fn => @{ $bindings->{ $fn } } );
}

our @EXPORT_OK = sort keys %{ $bindings };
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

1;
