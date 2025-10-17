#!/usr/bin/perl
# fs-to-File-TreeCreate.pl
# Copyright (C) Eskild Hustvedt 2025
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice (including the next
# paragraph) shall be included in all copies or substantial portions of the
# Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

use v5.20;
use strictures 2;
use feature 'signatures';
no warnings 'experimental::signatures';
use open            qw(:std :utf8);
use Data::Dumper    qw(Dumper);
use File::Basename  qw(basename);
use File::Find      qw(find);
use File::stat      qw(stat);
use Getopt::Long    qw(GetOptions);
use List::MoreUtils qw(any);

my $VERSION   = '0.1';
my $verbosity = 0;

# Reads a file into a scalar and returns it
sub slurp($file)
{
    open( my $in, '<', $file ) or die("Failed to open $file for reading: $!");
    local $/ = undef;
    my $content = <$in>;
    close($in);
    return $content;
}

# Simple usage info
sub usage($exit)
{
    my $name = basename($0);
    say "Usage: $name [options]";
    say "";
    say "Options:";
    say "  -h, --help                 Display this help screen and exit.";
    say
        "      --stub-pattern PTRN    Any files that match PTRN (using a substring match)";
    say
        "                             will have an empty \"content\" key, instead of the";
    say "                             actual file contents.";

    if ( defined $exit )
    {
        exit $exit;
    }
}

# Add a single path into a File::TreeCreate datastructure
sub addPathToTreeCreate( $TreeCreate, $path, $content )
{
    my $current    = $TreeCreate;
    my @components = split( '/', $path );
    if ( $components[0] eq '.' )
    {
        shift(@components);
    }
    if ( !$current->{name} || $current->{name} eq $components[0] . '/' )
    {
        $current->{name} = shift(@components) . '/';
    }
    my $last = pop(@components);
    while ( my $component = shift(@components) )
    {
        $component .= '/';
        $current->{subs} //= [];
        my $found;
        foreach my $sub ( @{ $current->{subs} } )
        {
            if ( $sub && $sub->{name} && $sub->{name} eq $component )
            {
                $found = $current = $sub;
                last;
            }
        }
        if ( !$found )
        {
            my $new = {
                name => $component,
                subs => [],
            };
            push( @{ $current->{subs} }, $new );
            $current = $new;
        }
    }
    push(
        @{ $current->{subs} },
        {   name    => $last,
            content => $content
        }
    );
}

# Convert a tree into File::TreeCreate datastructure
sub tree2treecreate( $directory, @stubFiles )
{
    chdir($directory) or die("Failed to chdir($directory): $!\n");
    my %TreeCreate;
    find(
        {   no_chdir => 1,
            wanted   => sub {
                return if -d $_;
                my $content = '';
                if ( -T $_ )
                {
                    if ( !any { index( $File::Find::name, $_ ) != -1 } @stubFiles )
                    {
                        $content = slurp($_);
                    }
                }
                addPathToTreeCreate( \%TreeCreate, $_, $content );
            },
        },
        './'
    );
    return \%TreeCreate;
}

sub main ()
{
    my @stubPatterns;
    Getopt::Long::Configure( 'no_ignore_case', 'bundling' );
    GetOptions(
        'help|h'  => sub { usage(0); },
        'version' => sub {
            say "fs-to-File-TreeCreate version $VERSION";
            exit(0);
        },
        'stub-pattern=s' => \@stubPatterns,
    ) or die;
    $Data::Dumper::Purity   = 1;
    $Data::Dumper::Varname  = 'TreeCreate';
    $Data::Dumper::Srotkeys = 1;
    my $directory = shift(@ARGV) || './';
    say Dumper( tree2treecreate( $directory, @stubPatterns ) );
}
main();
__END__
=encoding utf8

=head1 NAME

fs-to-File-TreeCreate.pl - build a data structure from a filesystem tree that
can be consumed with File::TreeCreate

=head1 SYNOPSIS

    fs-to-File-TreeCreate.pl /path

=head1 DESCRIPTION

This is a helper script that can turn a filesystem tree into a hash that you
can use with File::TreeCreate to build that same tree. For instance if you want
to convert a tree that is causing problems into a test to make sure the problem
doesn't reappear later.

It outputs (using Data::Dumper) a hashref that you can feed to
File::TreeCreate->create_tree().

Any text file is embedded into the datastructure, while any binary file has its
contents set to "".

=head1 OPTIONS

=head2 --stub-pattern PATTERN

If any file path B<case-sensitively> matches PATTERN through a substring match
will have its content key set to an empty string instead of the content of the
file. For instance if you wanted to make every markdown-file into empty files
in your test tree, you would use I<--stub-pattern .md>.

You can provide --stub-pattern multiple times.

=cut
