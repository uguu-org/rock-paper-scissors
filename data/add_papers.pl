#!/usr/bin/perl -w
# ./add_papers.pl {input.svg} > {output.svg}
#
# Adding slashed paper pieces for some subset of rotation+cut combinations.


use strict;
use Math::Trig;
use XML::LibXML;

use constant PI => 3.14159265358979323846264338327950288419716939937510;

# Center coordinate of first sprite.
use constant START_X => 32;
use constant START_Y => 2336;

# Output layer name.
use constant OUTPUT_LAYER => "generated papers";

# Paper size.
use constant WIDTH => 24;
use constant HEIGHT => 18;

# Maximum separation between cut pieces.
use constant SEPARATION_DISTANCE => 12;


# Serial number for generated IDs.  We need to add IDs to all generated
# elements, otherwise the <use> elements will be messed up.
my $id_serial = 1;

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
   return "gen_paper$id_serial";
}

# Rotate a point by a particular angle.
sub rotate($$$)
{
   my ($x, $y, $a) = @_;

   my $ca = cos($a);
   my $sa = sin($a);
   return
   (
      $ca * $x - $sa * $y,
      $sa * $x + $ca * $y,
   );
}

# Compute intersection point between a segment and an angled line.
sub intersect($$$$$)
{
   my ($angle, $ax, $ay, $bx, $by) = @_;

   my $dx = $bx - $ax;
   my $dy = $by - $ay;

   # px = ax + t * dx
   # py = ay + t * dy
   # py/px = tan(angle)
   #
   # py = tan(angle) * px
   #
   # px - dx * t = ax
   # tan(angle) * px - dy * t = ay
   #
   # Solving for px and t using Cramer's rule.
   # [a1 b1] [px]   [c1]
   # [a2 b2] [t]  = [c2]
   # a1 = 1           b1 = -dx   c1 = ax
   # a2 = tan(angle)  b2 = -dy   c2 = ay
   my $d = -$dy + $dx * tan($angle);
   if( $d == 0 )
   {
      return (undef, undef);
   }
   my $t = ($ay - $ax * tan($angle)) / $d;
   if( $t < 0 || $t > 1 )
   {
      return (undef, undef);
   }

   my $px = ($ax * (-$dy) + $dx * $ay) / $d;
   my $py = $ay + $t * $dy;
   return ($px, $py);
}

# Add a single piece of paper.
sub add_paper($$$$$$$)
{
   my ($dom, $center_x, $center_y,
       $paper_angle, $cut_angle, $separation, $opacity) = @_;

   # Compute corner coordinates.  These are screen coordinates, so positive
   # Y grows downwards.
   #  C-----D
   #  |     |
   #  B-----A
   my ($ax, $ay) = rotate(WIDTH * 0.5, HEIGHT * 0.5, $paper_angle);
   my ($bx, $by) = rotate(-WIDTH * 0.5, HEIGHT * 0.5, $paper_angle);
   my ($cx, $cy) = (-$ax, -$ay);
   my ($dx, $dy) = (-$bx, -$by);

   # Compute the cut coordinates, such that we get two quads:
   #  C-----D
   #  |     |
   #  Q-----P
   #  |     |
   #  B-----A
   my ($px, $py) = intersect($cut_angle, $ax, $ay, $dx, $dy);
   unless( defined($px) )
   {
      # Didn't work, rotate all coordinates and try again.
      #  C-----D       D-----A
      #  |     |   ->  |     |
      #  B-----A       C-----B
      $px = $ax; $ax = $bx; $bx = $cx; $cx = $dx; $dx = $px;
      $py = $ay; $ay = $by; $by = $cy; $cy = $dy; $dy = $py;
      ($px, $py) = intersect($cut_angle, $ax, $ay, $dx, $dy);
   }
   die unless (defined($px) && defined($py));
   my ($qx, $qy) = (-$px, -$py);

   # Compute separation vector to move ABQP away from the QP line.
   my $s = $separation / sqrt($px * $px + $py * $py);
   my $sx = -$py * $s;
   my $sy = $px * $s;

   # Add quads.
   my $group = XML::LibXML::Element->new("g");
   $group->{"id"} = generate_id();
   $dom->addChild($group);

   # Darken the paper in proportion to a drop in opacity.  This is so that
   # there are more black pixels left behind when a paper object is killed,
   # which shows up better against a white background.
   #
   # The background has to be white or mostly white, otherwise the black
   # scissors will not be visible.
   my $fill = int(255 * $opacity);
   $fill = sprintf '#%02x%02x%02x', $fill, $fill, $fill;

   $opacity = $opacity < 1 ? ";opacity:$opacity" : "";
   my $style = "fill:$fill;stroke:#000000;stroke-width:1;stroke-linecap:round;stroke-linejoin:round;paint-order:fill stroke markers$opacity";

   my $path = XML::LibXML::Element->new("path");
   $path->{"id"} = generate_id();
   $path->{"d"} =
      "M " .  ($ax + $sx + $center_x) . "," . ($ay + $sy + $center_y) .
      " L " . ($bx + $sx + $center_x) . "," . ($by + $sy + $center_y) .
      " " .   ($qx + $sx + $center_x) . "," . ($qy + $sy + $center_y) .
      " " .   ($px + $sx + $center_x) . "," . ($py + $sy + $center_y) .
      " z";
   $path->{"style"} = $style;
   $group->addChild($path);

   $path = XML::LibXML::Element->new("path");
   $path->{"id"} = generate_id();
   $path->{"d"} =
      "M " .  ($cx - $sx + $center_x) . "," . ($cy - $sy + $center_y) .
      " L " . ($dx - $sx + $center_x) . "," . ($dy - $sy + $center_y) .
      " " .   ($px - $sx + $center_x) . "," . ($py - $sy + $center_y) .
      " " .   ($qx - $sx + $center_x) . "," . ($qy - $sy + $center_y) .
      " z";
   $path->{"style"} = $style;
   $group->addChild($path);
}


unless( $#ARGV == 0 )
{
   die "$0 {input.svg} > {output.svg}\n";
}

my $dom = XML::LibXML->load_xml(location => $ARGV[0]);
my $output = find_layer_by_name($dom, OUTPUT_LAYER);

for(my $y = 0; $y < 8; $y++)
{
   for(my $x = 0; $x < 8; $x++)
   {
      for(my $f = 0; $f < 4; $f++)
      {
         add_paper($output,
                   START_X + $x * 128,
                   START_Y + $y * 256 + $f * 64,
                   ($x / 8.0) * PI,
                   ($y / 8.0) * PI,
                   ($f / 8.0) * SEPARATION_DISTANCE,
                   1.0);
      }
      for(my $f = 0; $f < 4; $f++)
      {
         add_paper($output,
                   START_X + $x * 128 + 64,
                   START_Y + $y * 256 + $f * 64,
                   ($x / 8.0) * PI,
                   ($y / 8.0) * PI,
                   (($f + 4) / 8.0) * SEPARATION_DISTANCE,
                   0.8 - 0.23 * $f);
      }
   }
}

# Dump updated SVG to stdout.
print $dom->toString;
