#!/usr/bin/env perl

# A Perforce wrapper that I can implement my own commands and aliases

use strict;
use warnings;

# core
use Cwd;
use File::Basename;
use File::Copy;
use File::Spec::Functions;
use File::Spec;
use Getopt::Long;
use Term::ANSIColor;
use Text::Wrap;

# CPAN
use File::Find::Rule;

my $command = shift(@ARGV);

my @command_args = @ARGV;

my %commands;
%commands = (
    'blame' => {
        'description' => 'Print the annotations of a file with the change list number and user responsible',
        'cmd'         => \&p4_blame,
    },
    'clean' => {
        'description' => 'Remove all files not in the depot',
        'cmd'         => \&p4_clean,
    },
    'diff' => {
        'description' => q(Shortcut for 'diff -du $@ | $PAGER'),
        'cmd'         => \&p4_diff,
    },
    'd' => {
        'description' => q(Shortcut for 'diff -du $@ | $PAGER'),
        'cmd'         => \&p4_diff,
    },
    'dc' => {
        'description' => q(Shortcut for 'diff -du $@', but with color!),
        'cmd'         => \&p4_diff_colored,
    },
    'dc2' => {
        'description' => q(Shortcut for 'diff2 -du $@', but with color and identical files filtered out!),
        'cmd'         => \&p4_diff2_colored,
    },
    'de' => {
        'description' => q(Shortcut for 'describe -du $@ | $PAGER'),
        'cmd'         => \&p4_describe,
    },
    'd3' => {
        'description' => q(Shortcut for 'diff2 -du -q $@ | $PAGER'),
        'cmd'         => \&p4_diff3,
    },
    'i' => {
        'description' => q(Shortcut for 'login -a < $HOME/.p4passwd'),
        'cmd'         => \&p4_login,
    },
    'last-change' => {
        'description' => 'Show the last change number',
        'cmd'         => \&p4_last_change,
    },
    'h' => {
        'description' => 'Show extended help',
        'cmd'         => \&p4_help,
    },
    'log' => {
        'description' => q(Shortcut for 'changes -t -m 1000 -l $@ ... | $PAGER'),
        'cmd'         => \&p4_log,
    },
    'o' => {
        'description' => q(Shortcut for 'opened | $PAGER'),
        'cmd'         => \&p4_opened,
    },
    'review-diff' => {
        'description' => q(Shortcut for 'diff ... | vim -'),
        'cmd'         => \&p4_review_diff,
    },
    'show' => {
        'description' => q(Shortcut for 'changes -m 10 -l with each change described with color'),
        'cmd'         => \&p4_show,
    },
    'stash' => {
        'description' => 'Stash local changes',
        'cmd'         => \&p4_stash,
    },
    'status' => {
        'description' => 'Show all files not added to the depot',
        'cmd'         => \&p4_status,
    },
    'unstash' => {
        'description' => 'Unstash local changes',
        'cmd'         => \&p4_unstash,
    },
);

unless ($ENV{'PAGER'}) {
    $ENV{'PAGER'} = 'more';
}

my $p4bin;
my @p4_bin_dirs = qw(/opt/perforce/bin/p4 /usr/local/bin/p4 /usr/bin/p4 /bin/p4);

foreach (@p4_bin_dirs) {
    if (-x $_) {
        print("Using '$_' as p4 binary\n") if ($ENV{'P4DEBUG'});
        $p4bin = $_;
        last;
    }
}

unless ($p4bin) {
    die("No suitable p4 binary found, aborting\n");
}

unless ($command) {
    p4_exec(qq(help));
}

if (exists($commands{$command})) {
    unless (defined(&{$commands{$command}->{'cmd'}})) {
        die("Error, no sub routine for sub command '$command'\n");
    }

    exit($commands{$command}->{'cmd'}->());
}
else {
    p4_exec($command, @command_args);
}

sub run {
    print("exec()ing '@_'\n") if ($ENV{'P4DEBUG'});
    return if ($ENV{'P4PRETEND'});
    exec(@_) || die($!);
}

sub p4_system {
    my @cmd = ('/bin/sh', '-c', "$p4bin @_");
    print('system()ing ', @cmd, "\n") if ($ENV{'P4DEBUG'});
    return if ($ENV{'P4PRETEND'});

    system(@cmd);

    if ($? == -1) {
        print "failed to execute: $!\n";
    }
    elsif ($? & 127) {
        printf "child died with signal %d, %s coredump\n", ($? & 127), ($? & 128) ? 'with' : 'without';
    }
    else {

        #   printf "child exited with value %d\n", $? >> 8;
    }
}

sub p4_system_output {
    my @cmd = ('/bin/sh', '-c', "'$p4bin @_'");
    print('system()ing ', join(' ', @cmd), "\n") if ($ENV{'P4DEBUG'});
    return if ($ENV{'P4PRETEND'});
    my $c = join(' ', @cmd);
    my @data = `$c`;
    return @data;
}

sub p4_exec {
    my @cmd = ('/bin/sh', '-c', "$p4bin @_");
    print('exec()ing ', @cmd, "\n") if ($ENV{'P4DEBUG'});
    return if ($ENV{'P4PRETEND'});
    exec(@cmd) || die($!);
}

sub p4_blame {
    my @output = p4_system_output(qq(annotate -i -q @command_args));

    my %user_changes_cache;

    foreach my $line (@output) {
        $line =~ m/^(\d+):/;

        my $change = $1;
        unless ($user_changes_cache{$change}) {
            my @d = `$p4bin change -o $change`;

            my @user = grep { /^User:\s*(\w+)\s*$/ } @d;
            my $user = $user[0];
            $user =~ m/^User:\s*(\w+)\s*$/;

            $user_changes_cache{$change} = $1;
        }
        $line =~ s/${change}://;
        print(color('blue'), sprintf("%6s", $change), color('reset'), ' ');
        print(color('red'), sprintf("%9s", $user_changes_cache{$change}), color('reset'), ': ');
        print($line);
    }
}

sub p4_clean {
    my @in_depot = qx($p4bin have @command_args);
    my $c        = cwd();
    my @files    = File::Find::Rule->file()->in($c);
    my %have;

    for (@in_depot) {

        # $1=p4name $2=version $3=filename
        /(.*)#(\d+) - (.*)/;
        $have{$3} = 1;
    }

    for (sort { $a cmp $b } @files) {
        unless (exists($have{$_})) {
            my $f = File::Spec->abs2rel($_, $c);
            if ($ENV{'P4PRETEND'}) {
                print('Would run unlink(', $f, ')', "\n");
            }
            else {
                printf("Removing %s\n", $f);
                unlink($f) || warn("unlink() on '$f' failed: $!");
            }
        }
    }
}

sub p4_diff {
    p4_exec(qq(diff -du @command_args | $ENV{'PAGER'}));
}

sub p4_diff_colored {
    my @data = qx($p4bin diff -du @command_args);

    @data = colorize_diff(@data);

    print(@data);
}

sub p4_diff2_colored {
    my @data = qx($p4bin diff2 -du @command_args);

    @data = grep { !/==== identical$/ } @data;

    @data = colorize_diff(@data);

    print(@data);
}

sub p4_describe {
    my @data = qx($p4bin describe -du @command_args);

    @data = colorize_diff(@data);

    print(@data);
}

sub p4_diff3 {

    p4_exec(qq(diff2 -du -q @command_args | $ENV{'PAGER'}));
}

sub p4_login {
    my $pwd_file = catfile($ENV{'HOME'}, '.p4passwd');

    unless (-r $pwd_file) {
        die("Please put your Perforce login password in '$pwd_file'\n");
    }

    p4_exec(qq(login -a < $pwd_file));
}

sub p4_help {
    print("Additional commands available:\n");

    foreach (sort(keys(%commands))) {
        print('  ', '  ', $_ . ' - ' . $commands{$_}->{'description'}, "\n");
    }
}

sub p4_last_change {
    p4_exec(q(changes -m 1 ... | awk '{ print $2 }'));
}

sub p4_log {
    my @data = qx($p4bin changes -t -l -m 1000 @command_args);

    @data = colorize_diff(@data);

    print(@data);
}

sub p4_opened {
    p4_exec(qq(opened | $ENV{'PAGER'}));
}

sub p4_review_diff {
    p4_exec(qq(diff ... | vim -));
}

sub p4_show {
    my @changes = qx($p4bin changes -u $ENV{'USER'} -m 10 -l @command_args);

    my @diff;

    foreach my $c (@changes) {
        if (@diff) {
            @diff = colorize_diff(@diff);

            print($_) for (@diff);
            @diff = ();
        }

        if ($c =~ /^Change\s*(\d+) /) {
            @diff = qx($p4bin describe -du $1);
        }
        else {
            print($c);
        }
    }
}

sub p4_status {
    my @in_depot = qx($p4bin have ...);
    my $c        = cwd();
    my @files    = File::Find::Rule->file()->in($c);
    my %have;

    for (@in_depot) {

        # $1=p4name $2=version $3=filename
        /(.*)#(\d+) - (.*)/;
        $have{$3} = 1;
    }

    for (sort { $a cmp $b } @files) {
        unless (exists($have{$_})) {
            printf("? %s\n", File::Spec->abs2rel($_, $c));
        }
    }
}

sub p4_stash {
    return unless (@command_args);
    for (@command_args) {
        next unless (-e $_ && -f $_);
        my $file = File::Spec->canonpath($_);
        my ($name, $path) = fileparse($file);
        my $stashed_file = File::Spec->catfile($path, sprintf(".%s_stashed", $name));
        if (copy($file, $stashed_file)) {
            printf("Stashed %s\n", $file);
            p4_system("revert $file");
        }
    }
}

sub p4_unstash {
    return unless (@command_args);
    for (@command_args) {
        next unless (-e $_ && -f $_);
        my $file = File::Spec->canonpath($_);
        my ($name, $path) = fileparse($file);
        my $stashed_file = File::Spec->catfile($path, sprintf(".%s_stashed", $name));
        if (move($stashed_file, $file)) {
            printf("Unstashed %s\n", $_);
            p4_system("edit $file");
        }
    }
}

sub colorize_diff {
    my @data = @_;

    map {
        if (/^-/) {
            $_ = color('red') . $_ . color('reset');
        }
        elsif (/^\+/) {
            $_ = color('green') . $_ . color('reset');
        }
        elsif (/^==== /) {
            $_ = color('reverse') . $_ . color('reset');
        }
        elsif (/^Change/) {
            $_ = color('reverse') . $_ . color('reset');
        }
    } @data;

    return @data;
}
