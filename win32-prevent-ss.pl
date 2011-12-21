#!perl -w

# I used this to prevent the SOX mandated lock screen from triggering on a
# system where I had insufficient privileges to disable

# It has a nice side effect that if you RDP in, the remote mouse doesn't
# actually move

use strict;
use warnings;

use Win32::GuiTest qw(:ALL);

my $offset = 1;

do {
   my ($x, $y) = GetCursorPos();

   MouseMoveAbsPix($x + $offset, $y + $offset);

   $offset = -$offset;

} while (sleep(60));
