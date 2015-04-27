package Parqus;
use Moo;
use namespace::autoclean;
use Regexp::Grammars;

# ABSTRACT: parse a search query string

=head1 SYNOPSIS

    use Parqus;
    my $parser = Parqus->new( keywords => [ qw/name title/ ] );
    my $res    = $parser->process('title:"bar baz" foo title: meh');
    # {
    #   words    => ['foo'],
    #   keywords => {
    #                 title => [
    #                            'bar baz',
    #                            'meh',
    #                          ]
    #               },
    # }

=head1 DESCRIPTION

Parqus (PArse QUery String) parses a search-engine like string into a perl structure

=head1 SEE ALSO

L<Regexp::Grammars>

=cut

has keywords => (
    is  => 'lazy',
    isa => sub {
        "$_[0] is not a HashRef!"
          unless ref $_[0] eq 'HASH';
    },
    coerce => sub {
        if ( ref $_[0] eq 'ARRAY' ) {
            my %hash = map { $_ => 1 } @{ $_[0] };
            return \%hash;
        }
    },
    default => sub { {} },
);

has parser => (
    is       => 'lazy',
    init_arg => undef,
    isa      => sub {
        "$_[0] is not a Regexp!"
          unless ref $_[0] eq 'Regexp';
    },
);
my %keywords = ( title => 1, name => 1 );

sub _build_parser {
    my ($self) = @_;

    # TODO: make keywords attr work with Regexp::Grammar
    #my %keywords = %{ $self->keywords };
    return qr/
                    <timeout: 3>
                    ^
                    \s*
                    <[query]>*
                    \s*
                    $
                    <rule: query>
                        <item>|<item><query>
                    <rule: item>
                        <keyvalue>|<word>|<word= quote>
                    <rule: word>
                        <MATCH= ([\w]+)>
                    <rule: keyvalue>
                        <key>:<value>?
                    <rule: key>
                        <%keywords>
                    <rule: value>
                        <str= quote>|<str= word>
                    <token: delim>
                        ['"]
                    <token: quote>
                        <ldelim=delim><MATCH= (.*?)><rdelim=\_ldelim>
                 /xms;

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
                  ? $item->{item}{keyvalue}{value}{str}
                  : '';
                push( @{ $keywords{$key} }, $value );
            }
            elsif ( exists $item->{item}{word} ) {
                push( @words, $item->{item}{word} );
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
