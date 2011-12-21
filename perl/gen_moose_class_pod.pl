#!/usr/bin/env perl

# About: use this script to auto generate POD documentation for Moose-based
# classes

# Note: this script is missing polish

use strict;
use warnings;

# core
use Cwd qw(cwd);
use Data::Dumper;
use Text::Wrap;

# CPAN
use Class::MOP;
use DateTime;
use Try::Tiny;

$Text::Wrap::columns = 80;

my $class = shift(@ARGV);

unless ($class) {
    die("Usage: $0 <Moose class name>");
}

try {
    Class::MOP::load_class($class);
}
catch {
    die("Failed to load $class", shift);
};

# HACK: if objects need to be created with required arguments
my %req = (
);

my $obj;

if (exists($req{$class})) {
    $obj = $class->new($req{$class});
}
else {
    $obj = $class->new;
}

print "=head1 NAME\n\n";

print "$class - XXX\n\n";

print "=head1 VERSION\n\n";

print '$Change:$', "\n\n";

print "=head1 DESCRIPTION\n\n";

print "XXX\n\n";

print "=head1 SYNOPSIS\n\n";

print "    use $class;\n\n";

print "    XXX\n\n";

my @roles;

foreach my $role (@{$obj->meta->roles}) {
    push(@roles, split(qr(\|), $role->name));
}

if (@roles) {
    print "=head1 ROLES\n\n";
    print 'L<', join('>, L<', sort @roles), ">\n\n";
}

print "=head1 ATTRIBUTES\n\n";

my @required;
my @not_required;

my @attribs = $obj->meta->get_attribute_list;

foreach my $attrib (@attribs) {
    if ($obj->meta->get_attribute($attrib)->is_required) {
        push(@required, $attrib);
    }
    else {
        push(@not_required, $attrib);
    }
}
@required     = sort @required;
@not_required = sort @not_required;

print "=head2 Required Attributes\n\n";

print "=over\n\n";

for my $attribute (@required) {
    my $d = $obj->meta->get_attribute($attribute);

    next if ($d->{'definition_context'}->{'package'} ne $class);

    #has_type_constraint
    my $i =
        '=item * '
      . "B<$attribute> ("
      . $d->{'is'} . ', '
      . $d->type_constraint->name . ') - '
      . ($d->has_documentation ? $d->documentation : 'XXX')
      . ($d->has_default
        ? q( Defaults to ') . ($d->is_default_a_coderef ? $d->default->() . q(') : $d->default . q('))
        : '')
      . ".\n\n";

    print "$i\n";
}

print "=back\n\n";

print "=head2 Optional Attributes\n\n";

print "=over\n\n";

for my $attribute (@not_required) {
    my $d = $obj->meta->get_attribute($attribute);

    if (exists($d->{'definition_context'}->{'package'})) {
        next if ($d->{'definition_context'}->{'package'} ne $class);
    }

    my $i =
        '=item * '
      . "B<$attribute> ("
      . $d->{'is'} . ', '
      . $d->type_constraint->name . ') - '
      . ($d->has_documentation ? $d->documentation : 'XXX')
      . ($d->has_default
        ? q( Defaults to ') . ($d->is_default_a_coderef ? $d->default->() . q(') : $d->default . q('))
        : '')
      . ".\n\n";

    print "$i";
}

print "=back\n\n";

print "=head1 PUBLIC API METHODS\n\n";

print "=over\n\n";

@attribs = $obj->meta->get_attribute_list;
my @methods = $obj->meta->get_all_methods;
@methods = sort { $a->name cmp $b->name } @methods;

foreach my $method (@methods) {
    next if ($method->name =~ /^_/);
    next if ($method->name =~ /^clear_/ || $method->name =~ /^has_/ || $method->name =~ /^new/);
    next
      if (
        $method->name ~~ [
            qw(dump DEMOLISHALL BEGIN new AUTHORITY DEMOLISH can import VERSION ISA DOES BUILD BUILDALL DEMOLISHALL meta DESTROY BUILDARGS does instance initialize)
        ]
      );
    next if ($method->name ~~ \@attribs);

    print '=item * B<' . $method->name, "()> - XXX\n\n";
}

print "=back\n\n";

print "=head1 AUTHORS\n\n";

print "XXX\n\n";

print "=head1 LICENSE AND COPYRIGHT\n\n";

print 'Copyright ' . DateTime->now->year . "\n";
