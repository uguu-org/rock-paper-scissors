#!/usr/bin/perl -w
# Parse the output of generate_animation_frames.pl and write the selected
# images to console.  This is to verify that we got the indices right.
#
# make -j && perl extract_animation_frames.pl t_animation_frames.lua
#
# Takes ~30 minutes to run because that's how long it takes to launch
# ImageMagick 1184 times.  But we weren't planning on running this script
# more than once anyways.

use strict;

my $image = undef;
my $image_w = undef;
my $tile_w = undef;
my $tile_h = undef;

my $line_number = 0;
while( my $line = <> )
{
   $line_number++;

   if( $line =~ /\{((?:\d+,\s*)*\d+)}/ )
   {
      # Got a line containing a set of animation frames.
      my $items = $1;
      my @indices = split /, /, $items;
      defined($image) or die;

      # Initialize empty canvas.
      my $output_w = $tile_w * (scalar @indices);
      my $cmd = "convert -size ${output_w}x${tile_h} xc:\"#0000ff\"";

      # Composite each tile.
      my $ox = 0;
      foreach my $i (@indices)
      {
         my $x = (($i - 1) % ($image_w / $tile_w)) * $tile_w;
         my $y = int(($i - 1) / ($image_w / $tile_w)) * $tile_h;
         $cmd .= ' "("' .
                 " $image -crop ${tile_w}x${tile_h}+${x}+${y}" .
                 " -geometry +${ox}+0".
                 ' ")" -composite';
         $ox += $tile_w;
      }

      # Output to stdout.
      $cmd .= " six:-";

      $line =~ s/^\s*//;
      print "Line $line_number: $line";
      system $cmd;
   }
   elsif( $line =~ /\((\w+-table-(\d+)-(\d+)\.png)\)/ )
   {
      # Got a line specifying which image table to use.
      $image = $1;
      $tile_w = $2;
      $tile_h = $3;
      my @image_size = `file $image`;
      $image_size[0] =~ /^[^:]*:\s*PNG.*?(\d+) x \d+,/ or die;
      $image_w = $1;
   }
}
