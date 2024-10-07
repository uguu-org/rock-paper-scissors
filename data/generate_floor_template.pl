#!/usr/bin/perl -w
# Generate a template SVG for drawing floor tiles.
#
# Usage:
#
#     ./generate_floor_template.pl > {floor.svg}
#
# This script is used to produce a SVG that would satisfy the edge tiling
# requirements, since it's tedious to check the bits of each tile index
# manually.  That said, the output of this script is expected to be
# manually adjusted, since it's difficult to automatically generate the
# kind of details we wanted.
#
# This script is nondeterministic.  The expected use case is to run it
# repeatedly until we get roughly what we wanted, then we manually edit
# that output and never run this script again.

use strict;
use XML::LibXML;

use constant PI => 3.14159265358979323846264338327950288419716939937510;

# Edge length of a single tile, in pixels.
use constant TILE_SIZE => 64;

# Number of oblique edges in each generated polygon.
use constant EDGE_STEPS => 11;

# Where to add output elements.
use constant LAYER_PREFIX => "floor -";

# Tile background color.
use constant BG_COLOR => "#e0e0e0";

# Polygon fill colors.
use constant FG_COLOR1 => "#ffffff";
use constant FG_COLOR2 => "#f0f0f0";


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

# Generate base SVG with placeholder groups.
sub base_svg()
{
   my $output_prefix = LAYER_PREFIX;
   my $width = (16 * 2 + 1) * TILE_SIZE;
   my $height = (16 * 2 + 1) * TILE_SIZE;
   my $bg_color = BG_COLOR;
   my $tile_size = TILE_SIZE;

   return <<"EOT";
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg
   width="$width"
   height="$height"
   viewBox="0 0 $width $height"
   sodipodi:docname="floor.svg"
   inkscape:export-filename="floor.png"
   inkscape:export-xdpi="96"
   inkscape:export-ydpi="96"
   xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape"
   xmlns:sodipodi="http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd"
   xmlns="http://www.w3.org/2000/svg"
   xmlns:svg="http://www.w3.org/2000/svg">
   <sodipodi:namedview
      id="namedview1"
      pagecolor="#ffffff"
      bordercolor="#666666"
      borderopacity="1.0"
      inkscape:showpageshadow="2"
      inkscape:pageopacity="0.0"
      inkscape:pagecheckerboard="0"
      inkscape:deskcolor="#d1d1d1"
      showgrid="true"
      inkscape:zoom="1"
      inkscape:cx="512"
      inkscape:cy="512"
      inkscape:window-width="1920"
      inkscape:window-height="1057"
      inkscape:window-x="-8"
      inkscape:window-y="-8"
      inkscape:window-maximized="1">
      <inkscape:grid
         id="grid1"
         units="px"
         originx="0"
         originy="0"
         spacingx="$tile_size"
         spacingy="$tile_size"
         empcolor="#3f3fff"
         empopacity="0.25098039"
         color="#3f3fff"
         opacity="0.1254902"
         empspacing="4"
         enabled="true"
         visible="true" />
   </sodipodi:namedview>
   <g
      inkscape:groupmode="layer"
      id="layer1"
      inkscape:label="$output_prefix background">
      <rect
         style="fill:$bg_color"
         width="$width"
         height="$height"
         x="0"
         y="0" />
   </g>
   <g
      inkscape:groupmode="layer"
      id="layer1"
      inkscape:label="$output_prefix shapes" />
</svg>
EOT
}

# Generate semicircle vertices.
sub semicircle_vertices($$$$)
{
   my ($cx, $cy, $start_angle, $scale) = @_;

   # Make sure first point is aligned to tile corner.
   my $points = "M ";
   if( $start_angle == 0 )
   {
      $points .= ($cx + TILE_SIZE / 2) . ",$cy";
   }
   elsif( $start_angle == 90 )
   {
      $points .= "$cx," . ($cy + TILE_SIZE / 2);
   }
   elsif( $start_angle == 180 )
   {
      $points .= ($cx - TILE_SIZE / 2) . ",$cy";
   }
   else
   {
      $points .= "$cx," . ($cy - TILE_SIZE / 2);
   }
   $points .= " L";

   # Apply scaling toward the flat edge.
   my $scale_x = 1;
   my $scale_y = 1;
   if( $start_angle == 0 || $start_angle == 180 )
   {
      $scale_y = $scale;
   }
   else
   {
      $scale_x = $scale;
   }

   # Add oblique edges.
   for(my $i = 1; $i < EDGE_STEPS; $i++)
   {
      my $a = ($start_angle + $i * 180 / EDGE_STEPS) * PI / 180 +
              (rand(0.8) - 0.4) * PI / EDGE_STEPS;
      my $r = (rand(0.2) + 0.8) * TILE_SIZE / 2;
      my $x = $r * cos($a) * $scale_x;
      my $y = $r * sin($a) * $scale_y;
      $x >= -TILE_SIZE / 2 && $x <= TILE_SIZE / 2 or die;
      $y >= -TILE_SIZE / 2 && $y <= TILE_SIZE / 2 or die;
      $points .= " " . ($x + $cx) . "," . ($y + $cy);
   }

   # Make sure last point is aligned to tile corner.
   $points .= " ";
   if( $start_angle == 0 )
   {
      $points .= ($cx - TILE_SIZE / 2) . ",$cy";
   }
   elsif( $start_angle == 90 )
   {
      $points .= "$cx," . ($cy - TILE_SIZE / 2);
   }
   elsif( $start_angle == 180 )
   {
      $points .= ($cx + TILE_SIZE / 2) . ",$cy";
   }
   else
   {
      $points .= "$cx," . ($cy + TILE_SIZE / 2);
   }

   return $points;
}

# Generate a shape covering a particular edge.
sub add_semicircle($$$$$)
{
   my ($output, $cx, $cy, $start_angle, $scale) = @_;

   my $path = XML::LibXML::Element->new("path");
   $path->{"d"} = semicircle_vertices($cx, $cy, $start_angle, $scale) . " z";
   $path->{"style"} = "fill:" . FG_COLOR1 . ";stroke:none";
   $output->addChild($path);
}

# Generate a shape covering 4 corners and 3 edges.
sub add_inverse_semicircle($$$$$)
{
   my ($output, $cx, $cy, $start_angle, $scale) = @_;

   my $points = semicircle_vertices($cx, $cy, $start_angle, $scale);

   # Cover the remaining two tile corners.
   $points .= " ";
   if( $start_angle == 0 )
   {
      $points .= ($cx - TILE_SIZE / 2) . "," . ($cy + TILE_SIZE) . " " .
                 ($cx + TILE_SIZE / 2) . "," . ($cy + TILE_SIZE);
   }
   elsif( $start_angle == 90 )
   {
      $points .= ($cx - TILE_SIZE) . "," . ($cy - TILE_SIZE / 2) . " " .
                 ($cx - TILE_SIZE) . "," . ($cy + TILE_SIZE / 2);
   }
   elsif( $start_angle == 180 )
   {
      $points .= ($cx + TILE_SIZE / 2) . "," . ($cy - TILE_SIZE) . " " .
                 ($cx - TILE_SIZE / 2) . "," . ($cy - TILE_SIZE);
   }
   else
   {
      $points .= ($cx + TILE_SIZE) . "," . ($cy + TILE_SIZE / 2) . " " .
                 ($cx + TILE_SIZE) . "," . ($cy - TILE_SIZE / 2);
   }

   my $path = XML::LibXML::Element->new("path");
   $path->{"d"} = "$points z";
   $path->{"style"} = "fill:" . FG_COLOR1 . ";stroke:none";
   $output->addChild($path);
}

# Generate a shape covering a particular corner.
sub add_quartercircle($$$$)
{
   my ($output, $cx, $cy, $start_angle) = @_;

   my $points = "M $cx,$cy L ";

   # Make sure first point is aligned to tile corner.
   if( $start_angle == 0 )
   {
      $points .= ($cx + TILE_SIZE) . ",$cy";
   }
   elsif( $start_angle == 90 )
   {
      $points .= "$cx," . ($cy + TILE_SIZE);
   }
   elsif( $start_angle == 180 )
   {
      $points .= ($cx - TILE_SIZE) . ",$cy";
   }
   else
   {
      $points .= "$cx," . ($cy - TILE_SIZE);
   }

   # Add oblique edges.
   for(my $i = 1; $i < EDGE_STEPS; $i++)
   {
      my $a = ($start_angle + $i * 90 / EDGE_STEPS) * PI / 180 +
              (rand(0.8) - 0.4) * (PI / 2) / EDGE_STEPS;
      my $r = (rand(0.2) + 0.8) * TILE_SIZE;
      my $x = $r * cos($a);
      my $y = $r * sin($a);
      $x >= -TILE_SIZE && $x <= TILE_SIZE or die;
      $y >= -TILE_SIZE && $y <= TILE_SIZE or die;
      $points .= " " . ($x + $cx) . "," . ($y + $cy);
   }

   # Make sure last point is aligned to tile corner.
   if( $start_angle == 0 )
   {
      $points .= " $cx," . ($cy + TILE_SIZE);
   }
   elsif( $start_angle == 90 )
   {
      $points .= " " . ($cx - TILE_SIZE) . ",$cy";
   }
   elsif( $start_angle == 180 )
   {
      $points .= " $cx," . ($cy - TILE_SIZE);
   }
   else
   {
      $points .= " " . ($cx + TILE_SIZE) . ",$cy";
   }

   my $path = XML::LibXML::Element->new("path");
   $path->{"d"} = "$points z";
   $path->{"style"} = "fill:" . FG_COLOR1 . ";stroke:none";
   $output->addChild($path);
}

# Add rectangle to output.
sub add_rectangle($$$$$)
{
   my ($output, $x, $y, $w, $h) = @_;

   my $rect = XML::LibXML::Element->new("rect");
   $rect->{"x"} = $x;
   $rect->{"y"} = $y;
   $rect->{"width"} = $w;
   $rect->{"height"} = $h;
   $rect->{"style"} = "fill:" . FG_COLOR1 . ";stroke:none";
   $output->addChild($rect);
}

# Add large polygons covering the edges.
sub add_large_poly($$$)
{
   my ($output, $tx, $ty) = @_;

   # Generate 0-based tile index, such that the upper 2 bits describe the
   # top and left edges (i.e. edges that current tile must match with),
   # and lower 2 bits describe the right and bottom edges (i.e. edges for
   # subsequent tiles to match against).  New tiles are generated by taking
   # 2 existing bits and adding 6 more random bits:
   #
   #             +-----+
   #             |     |
   #             |    1|
   #             |  0  |
   #             +-----+
   #    +-----+  +-----+
   #    |     |  |  6  |  Bit 6 of new tile is bit 0 from tile above.
   #    |    1|  |7 ?  |  Bit 7 of new tile is bit 1 from tile to the left.
   #    |  0  |  |     |  Bits 0..5 are random.
   #    +-----+  +-----+
   my $index = $ty * 16 + $tx;

   my $x = ($tx * 2 + 1) * TILE_SIZE;
   my $y = ($ty * 2 + 1) * TILE_SIZE;
   my $s = (($index >> 4) & 3) * 0.2 + 0.3;
   if( ($index & 0b11000011) == 0b11000011 )
   {
      # All edges are covered.
      add_rectangle($output, $x, $y, TILE_SIZE, TILE_SIZE);
   }
   elsif( ($index & 0b11000011) == 0b00000011 )
   {
      # Edges to the right and below.
      add_quartercircle($output, $x + TILE_SIZE, $y + TILE_SIZE, 180);
   }
   elsif( ($index & 0b11000011) == 0b10000001 )
   {
      # Edges to the left and below.
      add_quartercircle($output, $x, $y + TILE_SIZE, 270);
   }
   elsif( ($index & 0b11000011) == 0b01000010 )
   {
      # Edges to the right and above.
      add_quartercircle($output, $x + TILE_SIZE, $y, 90);
   }
   elsif( ($index & 0b11000011) == 0b11000000 )
   {
      # Edges to the left and above.
      add_quartercircle($output, $x, $y, 0);
   }
   elsif( ($index & 0b11000011) == 0b11000001 )
   {
      # Missing edge to the right.
      add_inverse_semicircle($output, $x + TILE_SIZE, $y + TILE_SIZE / 2, 90,
                             $s);
   }
   elsif( ($index & 0b11000011) == 0b01000011 )
   {
      # Missing edge to the left.
      add_inverse_semicircle($output, $x, $y + TILE_SIZE / 2, 270, $s);
   }
   elsif( ($index & 0b11000011) == 0b10000011 )
   {
      # Missing edge above.
      add_inverse_semicircle($output, $x + TILE_SIZE / 2, $y, 0, $s);
   }
   elsif( ($index & 0b11000011) == 0b11000010 )
   {
      # Missing edge below.
      add_inverse_semicircle($output, $x + TILE_SIZE / 2, $y + TILE_SIZE, 180,
                             $s);
   }
   else
   {
      if( ($index & 0b01000000) != 0 )
      {
         # Edge above.
         add_semicircle($output, $x + TILE_SIZE / 2, $y, 0, $s);
      }
      if( ($index & 0b10000000) != 0 )
      {
         # Edge to the left.
         add_semicircle($output, $x, $y + TILE_SIZE / 2, 270, $s);
      }
      if( ($index & 0b00000001) != 0 )
      {
         # Edge below.
         add_semicircle($output, $x + TILE_SIZE / 2, $y + TILE_SIZE, 180, $s);
      }
      if( ($index & 0b00000010) != 0 )
      {
         # Edge to the right.
         add_semicircle($output, $x + TILE_SIZE, $y + TILE_SIZE / 2, 90, $s);
      }
   }
}

# Add small polygons at some random spot within a tile.
sub add_small_poly($$$)
{
   my ($output, $tx, $ty) = @_;

   # Generate random contour.
   my @points = ();
   my ($min_x, $min_y, $max_x, $max_y);
   for(my $i = 0; $i < EDGE_STEPS; $i++)
   {
      my $a = ($i / EDGE_STEPS) * 2 * PI +
              (rand(0.8) - 0.4) * PI / EDGE_STEPS;
      my $r = (rand(0.2) + 0.2) * TILE_SIZE;
      my $x = $r * cos($a);
      my $y = $r * sin($a);
      push @points, [$x, $y];

      if( defined($min_x) )
      {
         $min_x = $min_x > $x ? $x : $min_x;
         $max_x = $max_x < $x ? $x : $max_x;
         $min_y = $min_y > $y ? $y : $min_y;
         $max_y = $max_y < $y ? $y : $max_y;
      }
      else
      {
         $min_x = $max_x = $x;
         $min_y = $max_y = $y;
      }
   }

   # Move the contour so that it's somewhere within tile range.
   my $dx = ($tx * 2 + 1) * TILE_SIZE - $min_x +
            rand(TILE_SIZE - ($max_x - $min_x));
   my $dy = ($ty * 2 + 1) * TILE_SIZE - $min_y +
            rand(TILE_SIZE - ($max_y - $min_y));

   # Build path data.
   my $d = "M " . ($points[0][0] + $dx) . "," . ($points[0][1] + $dy) . " L";
   for(my $i = 1; $i < EDGE_STEPS; $i++)
   {
      $d .= " " . ($points[$i][0] + $dx) . "," . ($points[$i][1] + $dy);
   }

   my $path = XML::LibXML::Element->new("path");
   $path->{"d"} = "$d z";
   $path->{"style"} = "fill:" . FG_COLOR2 . ";stroke:none";
   $output->addChild($path);
}

# Add extra polygons outside covered edges.
#
# We generate tiles that are larger than the final tile size, so that we
# can apply filters to all shapes more easily without affecting neighboring
# tiles.
sub extend_edges($$$)
{
   my ($output, $tx, $ty) = @_;

   my $index = $ty * 16 + $tx;
   my $x = ($tx * 2 + 1) * TILE_SIZE;
   my $y = ($ty * 2 + 1) * TILE_SIZE;

   if( ($index & 0b01000000) != 0 )
   {
      # Edge above.
      add_rectangle($output, $x, $y - TILE_SIZE / 2, TILE_SIZE, TILE_SIZE / 2);
   }
   if( ($index & 0b10000000) != 0 )
   {
      # Edge to the left.
      add_rectangle($output, $x - TILE_SIZE / 2, $y, TILE_SIZE / 2, TILE_SIZE);
   }
   if( ($index & 0b00000001) != 0 )
   {
      # Edge below.
      add_rectangle($output, $x, $y + TILE_SIZE, TILE_SIZE, TILE_SIZE / 2);
   }
   if( ($index & 0b00000010) != 0 )
   {
      # Edge to the right.
      add_rectangle($output, $x + TILE_SIZE, $y, TILE_SIZE / 2, TILE_SIZE);
   }
}


my $dom = XML::LibXML->load_xml(string => base_svg());
my $output = find_layer_by_name($dom, LAYER_PREFIX . " shapes");
for(my $ty = 0; $ty < 16; $ty++)
{
   for(my $tx = 0; $tx < 16; $tx++)
   {
      my $group = undef;
      if( ((($ty * 16) + $tx) & 0b11000011) != 0 )
      {
         $group = XML::LibXML::Element->new("g");
         add_large_poly($group, $tx, $ty);
         extend_edges($group, $tx, $ty);
      }
      if( (($tx + $ty) & 1) != 0 )
      {
         unless( defined($group) )
         {
            $group = XML::LibXML::Element->new("g");
         }
         add_small_poly($group, $tx, $ty);
      }
      if( defined($group) )
      {
         $output->addChild($group);
      }
   }
}
print $dom->toString;
