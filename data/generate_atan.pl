#!/usr/bin/perl -w
# Generate table for converting integer (dx,dy) to angles.
#
# This is effectively arc tangent with very limited domain and range.
#
# We could be doing some polynomial approximation instead, but that's
# slightly ugly due to the angle wraparound.  We went with tables since
# we got memory to spare, and we don't have that many angles.

use strict;
use constant PI => 3.14159265358979323846264338327950288419716939937510;

# Maximum range of input values.  Input table indexes must be in the range
# of [-INPUT_STEPS, INPUT_STEPS].
#
# Simulation tells us that the game completes slightly faster when we
# increase the accuracy from 32 to 64, but an increase to 128 actually
# makes the games finish slower.  So 64 seems like a good table size to
# settle on.
use constant INPUT_STEPS => 64;

# Number of angles in output.  Output table cell values will fall in the
# range of [1, OUTPUT_STEPS].
use constant OUTPUT_STEPS => 32;


sub get_angle($$)
{
   my ($x, $y) = @_;
   my $a = atan2($y, $x);
   if( $a < 0 ) { $a += 2 * PI; }
   if( $a >= 2 * PI ) { $a -= 2 * PI; }
   return int(($a / (2 * PI)) * OUTPUT_STEPS) + 1;
}

# Generate table with one of the delta values fixed at
# -INPUT_STEPS or INPUT_STEPS.
#
# Note that we generate table with two extra rows at INPUT_STEPS-1
# and INPUT_STEPS+1 to account for possible rounding issues.
my %table = ();
my $input_min = -INPUT_STEPS;
my $input_max = INPUT_STEPS;
for(my $x = $input_min - 1; $x <= $input_max + 1; $x++)
{
   $table{$x} = ();
   $table{$x}{$input_min} = get_angle($x, $input_min);
   $table{$x}{$input_max} = get_angle($x, $input_max);
}
for(my $y = $input_min - 1; $y <= $input_max + 1; $y++)
{
   $table{$input_min}{$y} = get_angle($input_min, $y);
   $table{$input_max}{$y} = get_angle($input_max, $y);
}

print "coarse_atan_steps = ", INPUT_STEPS, "\n",
      "coarse_atan =  -- Indexed by [dx][dy]\n",
      "{\n";
foreach my $x (sort {$a <=> $b} keys %table)
{
   print "\t[$x] =\n\t{\n";
   foreach my $y (sort {$a <=> $b} keys %{$table{$x}})
   {
      print "\t\t[$y] = $table{$x}{$y},\n";
   }
   print "\t},\n";
}
print "}\n";
