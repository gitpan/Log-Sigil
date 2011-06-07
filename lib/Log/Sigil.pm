package Log::Sigil;
use strict;
use warnings;
use base "Class::Singleton";
use Carp qw( carp croak );
use Readonly;
use Class::Accessor "antlers";
use Data::Dumper qw( Dumper );
use List::Util qw( first );

use constant DEBUG => 0;

Readonly my %DEFAULT => {
    sigils    => [ q{#}, qw( - ) ],
    repeats   => 3,
    delimiter => q{ },
};

our $VERSION = "0.09";

has "sigils";
has "repeats";
has "delimiter";
has "bias";
has "history";
has "splitter";

sub new {
    my $class = shift;
    carp "Call 'instance' to create a instance of this class insted.";
    return $class->instance;
}

sub _new_instance {
    my $class = shift;
    my %param = @_;
    my $self  = bless \%param, $class;

    foreach my $name ( keys %DEFAULT ) {
        $self->$name( $DEFAULT{ $name } )
            unless defined $self->$name;
    }

    $self->reset;

    return $self;
}

sub reset {
    my $self = shift;
    $self->history( [ ] );
    return $self;
}

sub format {
    my $self  = shift;
    my( $message, $is_suffix_needed )
        = @{ { @_ } }{qw( message is_suffix_needed )};
    my %depth = ( from => 0, history => 0 );
    my %context;
    my $prefix;
    my @suffixes;

    while ( @context{qw( package filename line subroutine )} = caller( ++$depth{from} ) ) {
        last
            if $context{subroutine} && 0 != index $context{subroutine}, __PACKAGE__;
    }
warn "!!! depth: from: $depth{from}"        if DEBUG;
warn "!!! package: $context{package}"       if DEBUG;
warn "!!! subroutine: $context{subroutine}" if DEBUG;

    my $name = first { defined $_ } ( @context{qw( subroutine package )}, q{} );
warn "!!! name: $name" if DEBUG;

    $depth{history}++
        while $depth{history} < @{ $self->history }
            && ${ $self->history }[ $depth{history} ] eq $name;
warn "!!! depth: history: $depth{history}" if DEBUG;

    # Just a safety for the array length.
    $depth{history} = $#{ $self->sigils }
        if $depth{history} > $#{ $self->sigils };
warn "!!! depth: history: $depth{history}" if DEBUG;

    $prefix = $self->sigils->[ $depth{history} ];

    unshift @{ $self->history }, $name;

    if ( $context{filename} && $context{line} && $is_suffix_needed ) {
        @suffixes  = ( "at", $context{filename}, "line", $context{line} );
warn "!!! suffixes is needed: ", join q{ }, @suffixes if DEBUG;
        $message   = join q{ }, $message, @suffixes;
    }

    return join $self->delimiter, ( $prefix x $self->repeats ), $message;
}

sub print {
    my $self  = shift;
    my %param = @_;
    my $FH    = delete $param{FH};

    $self->splitter( defined $, ? $, : q{} );

    local $,;

    print { $FH } $self->format(
        message          => join( $self->splitter, @{ $param{messages} } ),
        is_suffix_needed => $param{is_suffix_needed},
    ), "\n";

    return $self;
}

sub say {
    my $self     = shift;
    my @messages = @_;

    return $self->print(
        messages => \@messages,
        FH       => *STDOUT,
    );
}

sub warn {
    my $self             = shift;
    my @messages         = @_;
    my $is_suffix_needed = $messages[-1] !~ m{ [\n] \z}msx;

    return $self->print(
        messages         => \@messages,
        FH               => *STDERR,
        is_suffix_needed => $is_suffix_needed,
    );
}

sub dump {
    my $self     = shift;
    my @messages = @_;

    local $Data::Dumper::Terse = 1;

    return $self->print(
        messages         => [ map { Dumper( $_ ) } @messages ],
        FH               => *STDERR,
        is_suffix_needed => 1,
    );
}

1;
__END__

=head1 NAME

Log::Sigil - show warnings with sigil prefix

=head1 SYNOPSIS

  use Log::Sigil;
  my $log = Log::Sigil->new;

  $log->warn( "hi there." );                  # -> ### hi there.
  $log->warn( "a prefix will be changeed." ); # -> --- a prefix will be changed.

  package Foo;

  $log->warn( "When package is changed, prefix will be reset." );
    # -> ### When package is changed, prefix will be reset.

  package main;

  exit;

=head1 DESCRIPTION

Log::Sigil is a message formatter.  Formatting adds a few prefix,
and prefi is a sigil.  This module just add a few prefix to argument
of message, but prefix siginals where are you from.  Changing
sigil by "caller" has most/only things to this module exists.

*Note: this can [not] add a suffix of filename and line in the file
when called from [no] sub.  This depends on 'caller' function.

=head1 METHODS

=over

=item say

Likes say message with sigil prefix.

=item wran

Likes say, but file handle is specified STDERR.

=item dump

Likes warn, but args are changed by Data::Dumper::Dumper.

=back

=head1 PROPERTIES

=over

=item sigils

Is a array-ref which sorted by using order sigil.

=item repeats

Specifies how many sigil is repeated.

=item delimiter

Will be placed between sigil and log message.

=item bias

Controls changing of sigil.  But not installed yet.

=back

=head1 AUTHOR

kuniyoshi kouji E<lt>kuniyoshi@cpan.orgE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

