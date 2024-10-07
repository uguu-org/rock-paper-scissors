#!/usr/bin/perl -w
# Generate table of angles to slowly converge an input angle toward a target
# angle.
#
# new_angle = converge_angle[input_angle][target_angle]
#
# Where input_angle and target_angle are in the range of [1..ANGLE_STEPS]

use strict;

# Number of rotation steps in a full circle.
use constant ANGLE_STEPS => 32;

# Ratio of moving toward the converging angle.  At each converging step, if
# the current angle is not already the target angle, it will move at least
# one step or CONVERGE_RATIO*difference steps, whichever is larger.
use constant CONVERGE_RATIO => 0.25;

# Return value converted to integer, with minimum of 1.
sub at_least_one($)
{
   my ($value) = @_;
   return $value < 1 ? 1 : int($value);
}


print "converge_angle =\n{\n";
for(my $current = 0; $current < ANGLE_STEPS; $current++)
{
   if( $current > 0 )
   {
      printf '%4d', $current + 1;
   }
   else
   {
      print "\t-- 1";
   }
}
print "\n";

for(my $current = 0; $current < ANGLE_STEPS; $current++)
{
   print "\t{";
   for(my $target = 0; $target < ANGLE_STEPS; $target++)
   {
      if( $target > 0 ) { print ","; }
      if( $target == $current )
      {
         printf '%3d', $target + 1;
         next;
      }
      my ($clockwise, $counterclockwise);
      if( $target > $current )
      {
         $clockwise = $target - $current;
         $counterclockwise = ANGLE_STEPS - $clockwise;
      }
      else
      {
         $counterclockwise = $current - $target;
         $clockwise = ANGLE_STEPS - $counterclockwise;
      }
      my $angle = $clockwise < $counterclockwise
         ? $current + at_least_one($clockwise * CONVERGE_RATIO)
         : $current - at_least_one($counterclockwise * CONVERGE_RATIO);
      printf '%3d', ($angle + ANGLE_STEPS) % ANGLE_STEPS + 1;
   }
   print "},  -- ", $current + 1, "\n";
}
print "}\n";
