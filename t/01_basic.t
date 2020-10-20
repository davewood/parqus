#!/usr/bin/env perl
use FindBin qw/$Bin/;
use lib "$Bin/lib";
use Test::More;
use Test::Warnings;

BEGIN { use_ok('Parqus'); }

sub _parse_error {
    my ($res, $expected, $msg) = @_;
    ok( exists $res->{errors}, 'result has errors.');
    is( $res->{errors}[0], $expected, $msg );
    return $res;
}
sub _parse_ok {
    my ($parser, $query, $msg) = @_;
    $msg //= 'no parse error';
    my $res = $parser->process($query);
    ok( !exists $res->{errors}, $msg );
    return $res;
}

{
    my $parser = Parqus->new();
    ok( $parser, 'got a Parqus instance without passing keywords option.' );
    _parse_ok($parser, 'foo');
}

my $parser = Parqus->new( keywords => [qw/ title name /] );
ok( $parser, 'got a Parqus instance with passing keywords option.' );

{
    my $res = _parse_ok($parser, '');
    is_deeply( $res, {}, 'parse empty string.' );
}
{
    my $res = _parse_ok($parser, 'foo');
    is_deeply( $res, { words => ['foo'] }, 'parse single word.' );
}
{
    my $res = $parser->process('fo=o');
    _parse_error($res, 'Parse Error: Invalid search query.', 'found parse error.');
}
{
    my $parser = Parqus->new( value_regex => qr/[\w=-]+/ );
    ok( $parser, 'got a Parqus instance with custom value_regex.' );
    my $res = _parse_ok($parser, 'fo=o');
    is_deeply( $res, { words => ['fo=o'] }, 'parse unquoted word with special character.' );
}
{
    my $res = _parse_ok($parser, ' foo ');
    is_deeply( $res, { words => ['foo'] }, 'parse single word with leading and trailing whitespace.' );
}
{
    my $res = _parse_ok($parser, 'title: foo');
    is_deeply( $res, { keywords => { title => ['foo'] } }, 'parse single keyword.' );
}
{
    my $res = $parser->process('nokeyword: foo');
    _parse_error($res, 'Parse Error: Invalid search query.', 'found parse error.');
}
{
    my $res = _parse_ok($parser, '"nokeyword: foo"');
    is_deeply( $res, { words => ['nokeyword: foo'] }, 'parse quoted invalid keyword.' );
}
{
    my $res = _parse_ok($parser, '"foo bar"');
    is_deeply( $res, { words => ['foo bar'] }, 'parse quoted words.' );
}
{
    my $res = _parse_ok($parser, q/"I'am root&%$"/);
    is_deeply( $res, { words => [q/I'am root&%$/] }, 'parse quoted words with special chars.' );
}
{
    my $res = _parse_ok($parser, 'name:"foo bar"');
    is_deeply( $res, { keywords => { name => ['foo bar'] } }, 'parse keyword with quoted value.' );
}
{
    my $res = _parse_ok($parser, 'name:"foo bar" name:baz meh "mii"');
    my $expected = {
        words => [ 'meh' , 'mii' ],
        keywords => {
            name => ['foo bar', 'baz'],
        },
    };
    is_deeply( $res, $expected, 'mix words and keywords.' );
}
{
    my $res = $parser->process('&');
    _parse_error($res, 'Parse Error: Invalid search query.', 'found parse error.');
}

done_testing();
