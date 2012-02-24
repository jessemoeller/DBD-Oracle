#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More tests => 3;

use DBI;
use Encode;

unshift @INC ,'t';
require 'nchar_test_lib.pl';

my $dsn = oracle_test_dsn();
my $dbuser = $ENV{ORACLE_USERID} || 'scott/tiger';

$ENV{NLS_LANG} = 'AMERICAN_AMERICA.UTF8';
$ENV{NLS_NCHAR} = 'UTF8';

my $dbh = DBI->connect( $dsn, $dbuser, '',  { 
        PrintError => 0, AutoCommit => 0, RaiseError => 1, 
},);

$dbh->do(q(alter session set nls_territory = 'GERMANY'));

my $sth = $dbh->prepare(<<"END_SQL");
    SELECT ltrim(rtrim(to_char(0, 'L'))) FROM dual
END_SQL

$sth->execute;

my ($val);
$sth->bind_columns( \($val) );

$sth->fetch;

is Encode::is_utf8($val) => 1, "utf8 encoded";

$sth->finish;

$val = undef;

$sth = $dbh->prepare(<<'END_SQL');
declare
    l_ret       varchar2(10);
begin
    select  ltrim(rtrim(to_char(0, 'L')))
    into    l_ret
    from    dual;
    --
    :ret := l_ret;
end;
END_SQL

$sth->bind_param_inout(':ret', \$val, 100);
$sth->execute;

is Encode::is_utf8($val) => 1, "utf8 encoded";

$sth = $dbh->prepare(<<'END_SQL');
declare
    l_ret       varchar2(10);
begin
    select ltrim(rtrim(to_char(0, 'L'))) 
        || ltrim(rtrim(to_char(0, 'L'))) 
        || ltrim(rtrim(to_char(0, 'L'))) 
    into    l_ret
    from    dual;
    --
    :ret := l_ret;
end;
END_SQL

$val = undef;

# WARNING: does *not* truncate. DBD::Oracle doesn't heed the 3rd parameter
$sth->bind_param_inout(':ret', \$val, 1);
$sth->execute;

is Encode::is_utf8($val) => 1, "truncated, yet utf8 encoded";

$dbh->disconnect;
