package Parqus;

use Moo;
use namespace::autoclean;
use Regexp::Grammars;

# ABSTRACT: parse a search query string

=head1 SYNOPSIS

    use Parqus;
    my $parser = Parqus->new( keywords => [ qw/name title/ ] );
    my $res;

    $res = $parser->process('title:"bar baz" foo title: meh');
    # {
    #   words    => ['foo'],
    #   keywords => {
    #                 title => [
    #                            'bar baz',
    #                            'meh',
    #                          ]
    #               },
    # }

    $res = $parser->process('title:"bar baz" title: meh');
    # {
    #   keywords => {
    #                 title => [
    #                            'bar baz',
    #                            'meh',
    #                          ]
    #               },
    # }

    $res = $parser->process('foo bar baz');
    # {
    #   words => ['foo', 'bar', 'baz'],
    # }

    $res = $parser->process('tag: inactive');
    # {
    #   errors => {
    #               'Parse Error: Invalid search query.'
    #             },
    # }

=head1 DESCRIPTION

Parqus (PArse QUery String) parses a search-engine like string into a perl structure

=head1 NEW

    my $parser = Parqus->new( %options );

=head1 OPTIONS

=head2 keywords

    keywords => [ qw/name title/ ]

the list of keywords you want to recognise.

=head2 value_regex

regular expression to capture words. (default: C<[qr![\w-]+!xms]>)

=head1 SEE ALSO

L<Regexp::Grammars>,
L<Search::Query>,
L<Search::Query::Dialect::DBIxClass>

=cut

has keywords => (
    is  => 'lazy',
    isa => sub {
        die "$_[0] is not a HashRef!"
          if ref $_[0] ne 'HASH';
    },
    coerce => sub {
        if ( ref $_[0] eq 'ARRAY' ) {
            my %hash = map { $_ => 1 } @{ $_[0] };
            return \%hash;
        }
        else {
            return $_[0];
        }
    },
    default => sub { {} }
);


has value_regex => (
    is  => 'lazy',
    isa => sub {
        "$_[0] is not a Regexp!"
          unless ref $_[0] eq 'Regexp';
    },
    default => sub { qr![\w-]+!xms },
);

has parser => (
    is       => 'lazy',
    init_arg => undef,
    isa      => sub {
        "$_[0] is not a Regexp!"
          unless ref $_[0] eq 'Regexp';
    },
);

sub _build_parser {
    my ($self) = @_;

    my %keywords    = %{ $self->keywords };
    my $value_regex = $self->value_regex;
    return eval q{qr/
                    <timeout: 2>
                    ^
                    \s*
                    <[query]>*
                    \s*
                    $
                    <rule: query>
                        <item>|<item><query>
                    <rule: item>
                        <keyvalue>|<value>
                    <rule: keyvalue>
                        <key>:<value>?
                    <rule: key>
                        <%keywords>
                    <rule: delim>
                        ['"]
                    <rule: value>
                        <MATCH= ($value_regex)>|<ldelim=delim><MATCH= (.*?)><rdelim=\_ldelim>
                 /xms};
}

sub process {
    my ( $self, $query ) = @_;

    my %keywords = ();
    my @words    = ();
    my @errors   = ();
    if ( $query =~ $self->parser ) {
        for my $item ( @{ $/{query} } ) {
            if ( exists $item->{item}{keyvalue} ) {
                my $key = $item->{item}{keyvalue}{key};
                my $value =
                  exists $item->{item}{keyvalue}{value}
                  ? $item->{item}{keyvalue}{value}
                  : '';
                push( @{ $keywords{$key} }, $value );
            }
            elsif ( exists $item->{item}{value} ) {
                push( @words, $item->{item}{value} );
            }
            else {
                push( @errors, "Parse Error: neither word nor keyvalue" );
            }
        }
    }
    else {
        push( @errors, "Parse Error: Invalid search query." );
    }

    push( @errors, @! )
      if @!;

    return {
        ( scalar @words ? (words => \@words) : () ),
        ( scalar keys %keywords ? (keywords => \%keywords) : () ),
        ( scalar @errors ? (errors => \@errors) : () ),
    };
}

1;
