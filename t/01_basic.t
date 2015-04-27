#!/usr/bin/env perl
use FindBin qw/$Bin/;
use lib "$Bin/lib";
use Test::More;
use Test::Warnings;

BEGIN { use_ok('Parqus'); }

{
    my $parser = Parqus->new();
    ok( $parser, 'got a Parqus instance without passing keywords.' );
}

my $parser = Parqus->new( keywords => [qw/ title name /] );
ok( $parser, 'got a Parqus instance with passing keywords.' );

{
    my $res = $parser->process('');
    is_deeply( $res, {}, 'parse empty string.' );
}
{
    my $res = $parser->process('foo');
    is_deeply( $res, { words => ['foo'] }, 'parse single word.' );
}
{
    my $res = $parser->process('title: foo');
    is_deeply( $res, { keywords => { title => ['foo'] } }, 'parse single keyword.' );
}
{
    my $res = $parser->process('"foo bar"');
    is_deeply( $res, { words => ['foo bar'] }, 'parse quoted words.' );
}
{
    my $res = $parser->process('name:"foo bar"');
    is_deeply( $res, { keywords => { name => ['foo bar'] } }, 'parse keyword with quoted value.' );
}
{
    my $res = $parser->process('name:"foo bar" name:baz meh "mii"');
    my $expected = {
        words => [ 'meh' , 'mii' ],
        keywords => {
            name => ['foo bar', 'baz'],
        },
    };
    is_deeply( $res, $expected, 'mix words and keywords.' );
}
{
    my $res = $parser->process('&&');
    ok( exists $res->{errors}, 'unquoted special chars causes error.');
    is( $res->{errors}[0], 'Parse Error: Invalid search query.', 'found parse error.' );
}

done_testing();
