#!/usr/bin/perl -w
# ./add_rocks.pl {input.svg} > {output.svg}
#
# The "rocks" are just icosahedrons rotated at various angles.


use strict;
use Math::Trig;
use XML::LibXML;

use constant PI => 3.14159265358979323846264338327950288419716939937510;
use constant PHI => (1 + sqrt(5)) / 2;

# Scaling ratio for icosahedron vertex coordinates.
use constant SCALE => 13 / PHI;

# Center coordinate of first sprite.
use constant LIVE_START_X => 16;
use constant LIVE_START_Y => 528;
use constant DEAD_START_X => 16;
use constant DEAD_START_Y => 1040;

# Output layer name.
use constant OUTPUT_LAYER => "generated rocks";

# Color scaling factor to darken shaded area.
use constant DARK_SCALE => 2.5;

# Amount of distance to move for maximum imploded face.
use constant IMPLODE_DISTANCE => 11;

# Serial number for generated IDs.  We need to add IDs to all generated
# elements, otherwise the <use> elements will be messed up.
my $id_serial = 1;

# Icosahedron coordinates.
my @vertices =
(
   [0.0, +1.0 * SCALE, +PHI * SCALE],
   [0.0, -1.0 * SCALE, +PHI * SCALE],
   [0.0, +1.0 * SCALE, -PHI * SCALE],
   [0.0, -1.0 * SCALE, -PHI * SCALE],

   [+1.0 * SCALE, +PHI * SCALE, 0.0],
   [-1.0 * SCALE, +PHI * SCALE, 0.0],
   [+1.0 * SCALE, -PHI * SCALE, 0.0],
   [-1.0 * SCALE, -PHI * SCALE, 0.0],

   [+PHI * SCALE, 0.0, +1.0 * SCALE],
   [+PHI * SCALE, 0.0, -1.0 * SCALE],
   [-PHI * SCALE, 0.0, +1.0 * SCALE],
   [-PHI * SCALE, 0.0, -1.0 * SCALE],
);
my @faces =
(
   [ 0, 10,  1],
   [ 0,  1,  8],
   [ 0,  8,  4],
   [ 0,  4,  5],
   [ 0,  5, 10],

   [10,  7,  1],
   [ 1,  7,  6],
   [ 1,  6,  8],
   [ 8,  6,  9],
   [ 8,  9,  4],
   [ 4,  9,  2],
   [ 4,  2,  5],
   [ 5,  2, 11],
   [ 5, 11, 10],
   [10, 11,  7],

   [ 3,  7, 11],
   [ 3,  6,  7],
   [ 3,  9,  6],
   [ 3,  2,  9],
   [ 3, 11,  2],
);

# Find layer where elements are to be added.
sub find_layer_by_name($$)
{
   my ($dom, $name) = @_;

   foreach my $group ($dom->getElementsByTagName("g"))
   {
      if( defined($group->{"inkscape:label"}) &&
          $group->{"inkscape:label"} eq $name )
      {
         return $group;
      }
   }
   die "Layer not found: $name\n";
}

# Generate a new unique ID.
sub generate_id()
{
   $id_serial++;
   return "gen_rock$id_serial";
}

# Generate a 3x3 rotation matrix along the Y axis.
sub rotate_y($)
{
   my ($a) = @_;

   my $ca = cos($a);
   my $sa = sin($a);
   return
   (
      $ca, 0, -$sa,
      0,   1, 0,
      $sa, 0, $ca,
   );
}

# Generate a 3x3 rotation matrix along the Z axis (pointing outside of screen).
sub rotate_z($)
{
   my ($a) = @_;

   my $ca = cos($a);
   my $sa = sin($a);
   return
   (
      $ca, -$sa, 0,
      $sa, $ca,  0,
      0,   0,    1,
   );
}

# Compute the product of [A] * [B].
sub multiply_matrix($$)
{
   my ($ma, $mb) = @_;

   return
   (
      $$ma[0] * $$mb[0] + $$ma[1] * $$mb[3] + $$ma[2] * $$mb[6],
      $$ma[0] * $$mb[1] + $$ma[1] * $$mb[4] + $$ma[2] * $$mb[7],
      $$ma[0] * $$mb[2] + $$ma[1] * $$mb[5] + $$ma[2] * $$mb[8],

      $$ma[3] * $$mb[0] + $$ma[4] * $$mb[3] + $$ma[5] * $$mb[6],
      $$ma[3] * $$mb[1] + $$ma[4] * $$mb[4] + $$ma[5] * $$mb[7],
      $$ma[3] * $$mb[2] + $$ma[4] * $$mb[5] + $$ma[5] * $$mb[8],

      $$ma[6] * $$mb[0] + $$ma[7] * $$mb[3] + $$ma[8] * $$mb[6],
      $$ma[6] * $$mb[1] + $$ma[7] * $$mb[4] + $$ma[8] * $$mb[7],
      $$ma[6] * $$mb[2] + $$ma[7] * $$mb[5] + $$ma[8] * $$mb[8],
   );
}

# Apply rotation to point.
sub apply_transform($$$$)
{
   my ($m, $x, $y, $z) = @_;

   return
   (
      $$m[0] * $x + $$m[1] * $y + $$m[2] * $z,
      $$m[3] * $x + $$m[4] * $y + $$m[5] * $z,
      $$m[6] * $x + $$m[7] * $y + $$m[8] * $z,
   );
}

# Compute cross product of A*B.
sub cross_product($$$$$$)
{
   my ($ax, $ay, $az, $bx, $by, $bz) = @_;

   return
   (
      $ay * $bz - $az * $by,
      $az * $bx - $ax * $bz,
      $ax * $by - $ay * $bx,
   );
}

# Compute the sum of all face Z values, used for sorting triangles.
sub sum_z($)
{
   my ($t) = @_;
   return $t->[0][2] + $t->[1][2] + $t->[2][2];
}

# Add an icosahedron to output.
sub add_icosahedron($$$$$$)
{
   my ($dom, $cx, $cy, $ry, $rz, $implode) = @_;

   my @mry = rotate_y($ry);
   my @mrz = rotate_z($rz);
   my @transform = multiply_matrix(\@mrz, \@mry);

   # Generate triangles.
   my @triangles = ();
   for(my $i = 0; $i < scalar @faces; $i++)
   {
      my @t = ();
      for(my $j = 0; $j < 3; $j++)
      {
         my $x = $vertices[$faces[$i][$j]][0];
         my $y = $vertices[$faces[$i][$j]][1];
         my $z = $vertices[$faces[$i][$j]][2];
         my @p = apply_transform(\@transform, $x, $y, $z);
         push @t, [@p];
      }
      push @triangles, [@t];
   }

   # Sort faces by Z values.
   @triangles = sort {sum_z($a) <=> sum_z($b)} @triangles;

   # Add new group to output.
   my $group = XML::LibXML::Element->new("g");
   $group->{"id"} = generate_id();
   $dom->addChild($group);

   # Add triangles to group.
   foreach my $i (@triangles)
   {
      # Compute face normal.
      my ($nx, $ny, $nz) = cross_product($i->[1][0] - $i->[0][0],
                                         $i->[1][1] - $i->[0][1],
                                         $i->[1][2] - $i->[0][2],
                                         $i->[2][0] - $i->[0][0],
                                         $i->[2][1] - $i->[0][1],
                                         $i->[2][2] - $i->[0][2]);

      # Check angle between normal vector and [-1,-1,1].  We will use a
      # darker shade if the angle exceeds a certain incidence angle.
      #
      # Angle can be computed using dot product:
      #  n * [-1,-1,1] = |n| * sqrt(3) * cos(angle)
      #  cos(angle) = (n * [-1,-1,1]) / (|n| * sqrt(3))
      my $fill = "#ffffff";
      my $opacity = "";
      my $dot = -$nx - $ny + $nz;
      my $nd = sqrt($nx * $nx + $ny * $ny + $nz * $nz);
      my $ca = $dot / ($nd * sqrt(3));
      my $angle = acos($ca);
      if( $angle > PI / 4 )
      {
         my $intensity = 1.0 - DARK_SCALE * ($angle - PI / 4) / (PI * 3 / 4);
         $intensity = $intensity > 0 ? int(255 * $intensity) : 0;
         $fill = sprintf '#%02x%02x%02x', $intensity, $intensity, $intensity;
      }

      # Optionally implode face along the normal direction.
      my $tx0 = $i->[0][0];
      my $ty0 = $i->[0][1];
      my $tx1 = $i->[1][0];
      my $ty1 = $i->[1][1];
      my $tx2 = $i->[2][0];
      my $ty2 = $i->[2][1];
      if( $implode > 0 )
      {
         # Reversing the signs here will make an exploding effect instead of
         # implode, but we went with implode because it looks nicer.
         #
         # We are drawing icosahedrons and not rocks, but we can kind of get
         # away with it because the rolling effects look neat enough to make
         # it worth while.  But if the faces were exploded, the individual
         # faces becomes very visible, and at that point it's obvious that
         # we are drawing hollow icosahedrons and not rocks.
         #
         # In comparison, imploding and translucent faces roughly resembles
         # crumbled papers when dithered, and it seems less of a stretch to
         # call those "rocks".
         my $dx = ($implode * IMPLODE_DISTANCE / $nd) * $nx;
         my $dy = ($implode * IMPLODE_DISTANCE / $nd) * $ny;
         $tx0 -= $dx;
         $ty0 -= $dy;
         $tx1 -= $dx;
         $ty1 -= $dy;
         $tx2 -= $dx;
         $ty2 -= $dy;
         $opacity = sprintf ';opacity:%f', (1.0 - $implode);
      }

      # Create path.
      my $path = XML::LibXML::Element->new("path");
      $path->{"id"} = generate_id();
      $path->{"d"} = "M " .  ($tx0 + $cx) . "," . ($ty0 + $cy) .
                     " L " . ($tx1 + $cx) . "," . ($ty1 + $cy) .
                     " " .   ($tx2 + $cx) . "," . ($ty2 + $cy) .
                     " z";

      $path->{"style"} = "fill:$fill;stroke:#000000;stroke-width:1;stroke-linecap:round;stroke-linejoin:round;paint-order:fill stroke markers$opacity";
      $group->addChild($path);
   }
}


unless( $#ARGV == 0 )
{
   die "$0 {input.svg} > {output.svg}\n";
}

my $dom = XML::LibXML->load_xml(location => $ARGV[0]);
my $output = find_layer_by_name($dom, OUTPUT_LAYER);

# Add live sprites.
for(my $y = 0; $y < 16; $y++)
{
   for(my $x = 0; $x < 32; $x++)
   {
      add_icosahedron($output,
                      LIVE_START_X + $x * 32,
                      LIVE_START_Y + $y * 32,
                      ($y / 16.0) * -PI,
                      ($x / 32.0) * 2.0 * PI,
                      0);
   }
}

# Add dead sprites.
for(my $y = 0; $y < 16; $y++)
{
   for(my $x = 0; $x < 32; $x++)
   {
      add_icosahedron($output,
                      DEAD_START_X + $x * 32,
                      DEAD_START_Y + $y * 32,
                      0,
                      ($x / 32.0) * 2.0 * PI,
                      ($y + 1) / 16.4);
   }
}

# Dump updated SVG to stdout.
print $dom->toString;
