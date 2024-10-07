#!/usr/bin/perl -w
# Generate three tables with precomputed velocities:
#
# velocity[kind][angle][frame] = {vx, vy}
# average_velocity[angle] = {vx, vy}
# slime_velocity[angle] = {vx, vy}
#
# Where {vx, vy} are fixed-point velocity values.

use strict;
use constant PI => 3.14159265358979323846264338327950288419716939937510;

# Number of bits to use for the fractional part.
use constant FRACTIONAL_BITS => 8;
use constant FIXED_POINT_SCALE => 1 << FRACTIONAL_BITS;

# Average velocity in pixels per frame.
use constant AVERAGE_SPEED => 3;
use constant SLIME_SPEED => 1;

# Number of animation frames.
use constant FRAMES => 16;

# Number of rotation steps.
use constant ANGLE_STEPS => 32;

# Rock velocities are constant throughout all frames.
#
#     V
#     ^..............
#     |
#     |
#     +--------------> T
my @rock = ();
for(my $i = 0; $i < FRAMES; $i++)
{
   push @rock, AVERAGE_SPEED;
}

# Paper velocities are higher in the first 1/4 of the frames, and
# gradually reduced to near zero at the end.
#
#     V
#     ^    .
#     |   .  .
#     |  .     .
#     | .        .
#     |.           .
#     +--------------> T
#
# We will try to capture the correct shape of the graph here, and
# apply some scaling later.
my @paper = ();
for(my $i = 1; $i <= FRAMES / 4; $i++)
{
   push @paper, $i;
}
for(my $i = 0; $i < FRAMES * 3 / 4; $i++)
{
   push @paper, 1.0 - $i / (FRAMES * 3 / 4);
}

# Scissors traverse for first half of the frames, after which it
# remains still.  For variety, we use a quadratic velocity curve here
# instead of piecewise linear.
#
# v = t * (frames/2 - t)
#
#     V
#     ^    ..
#     |   .  .
#     |  .    .
#     |
#     | .      .
#     |
#     +-------------> T
my @scissors = ();
for(my $i = 0; $i < FRAMES / 2; $i++)
{
   push @scissors, $i * (FRAMES / 2 - $i);
}
for(my $i = FRAMES / 2; $i < FRAMES; $i++)
{
   push @scissors, 0;
}

# Now we adjust the paper and scissors curves such that the total
# distance travelled is equal for all objects.
#
# Doing it this way gives us more freedom to adjust the shape of the
# curves, since we don't have to re-derive all the integral equations
# and such.  But actually, as it turns out, because we are sampling at
# discrete points along the velocity*time graph instead of integrating
# along all points, doing it this way also makes it possible to better
# match the total distances.
(scalar @paper) == (scalar @rock) or die;
(scalar @scissors) == (scalar @rock) or die;

my ($d0, $d1, $d2) = (0, 0, 0);
for(my $i = 0; $i < scalar @rock; $i++)
{
   $d0 += $rock[$i];
   $d1 += $paper[$i];
   $d2 += $scissors[$i];
}
for(my $i = 0; $i < scalar @rock; $i++)
{
   $paper[$i] *= $d0 / $d1;
   $scissors[$i] *= $d0 / $d2;
}

# Slimes moved at a constant 1 pixel per frame.
my @slime = ();
for(my $i = 0; $i < FRAMES; $i++)
{
   push @slime, 1;
}


# Convert a fractional velocity value to fixed point.
sub to_fixed_point($)
{
   my ($v) = @_;
   return $v < 0 ? -int(-$v * FIXED_POINT_SCALE + 0.5)
                 : int($v * FIXED_POINT_SCALE + 0.5);
}

# Output velocity table for a single kind.
sub output_velocities(@)
{
   my (@v) = @_;

   print "\t{\n";
   for(my $a = 0; $a < ANGLE_STEPS; $a++)
   {
      print "\t\t{\n";
      for(my $f = 0; $f < FRAMES; $f++)
      {
         print "\t\t\t{",
               to_fixed_point($v[$f] * cos($a / ANGLE_STEPS * 2 * PI)),
               ", ",
               to_fixed_point($v[$f] * sin($a / ANGLE_STEPS * 2 * PI)),
               "},\n";
      }
      print "\t\t},\n";
   }
   print "\t},\n";
}

# Output table with constant velocities.
sub output_constant_velocities($)
{
   my ($v) = @_;

   print "{\n";
   for(my $a = 0; $a < ANGLE_STEPS; $a++)
   {
      print "\t{",
            to_fixed_point($v * cos($a / ANGLE_STEPS * 2 * PI)),
            ", ",
            to_fixed_point($v * sin($a / ANGLE_STEPS * 2 * PI)),
            "},\n";
   }
   print "}\n";
}

print "velocity =\n",
      "{\n",
      "\t-- Rock.\n";
output_velocities(@rock);
print "\t-- Paper.\n";
output_velocities(@paper);
print "\t-- Scissors.\n";
output_velocities(@scissors);
print "}\n",
      "average_velocity =\n";
output_constant_velocities(AVERAGE_SPEED);
print "slime_velocity =\n";
output_constant_velocities(SLIME_SPEED);
