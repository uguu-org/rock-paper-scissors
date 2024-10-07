#!/usr/bin/perl -w
# Generate table of animation frames.
#
# We are encoding all frame indices in a static table, which makes sprites
# easier to test, and saves a little bit of arithmetic cost at run time.
# But basically we are doing this because we got memory to spare.

use strict;

# Number of animation frames when an object dies.
#
# We actually only have 8 frames, which we play at half speed for 16 frames
# total.  For the remainder of the sequence, we just repeat the final still
# frame.  We extend the number of dying frames so that when an object is
# killed, player gets to observe the object's death for a bit before the
# viewport shifts to follow the next live object.
use constant DEATH_FRAMES => 24;

print "animation_frame =\n",
      "{\n";

# {{{ Rock frames.
print "\t-- KIND_ROCK\n",
      "\t{\n",
      "\t\t-- STATE_DYING (sprites1-table-32-32.png)\n",
      "\t\t{\n";
for(my $a = 0; $a < 32; $a++)
{
   print "\t\t\t{";
   for(my $f = 0; $f < 16; $f++)
   {
      if( $f > 0 ) { print ", "; }
      print 1024 + $a + $f * 32 + 1;
   }
   for(my $f = 16; $f < DEATH_FRAMES; $f++)
   {
      print ", ", 1024 + $a + 15 * 32 + 1;
   }
   print "},\n";
}

print "\t\t},\n",
      "\t\t-- STATE_LIVE (sprites1-table-32-32.png)\n",
      "\t\t{\n";
for(my $a = 0; $a < 32; $a++)
{
   print "\t\t\t{";
   for(my $f = 0; $f < 16; $f++)
   {
      if( $f > 0 ) { print ", "; }
      print 512 + $a + $f * 32 + 1;
   }
   print "},\n";
}
print "\t\t}\n",
      "\t},\n";
# }}}

# {{{ Paper frames.
print "\t-- KIND_PAPER\n",
      "\t{\n",
      "\t\t-- STATE_DYING\n",
      "\t\t{},  -- See paper_frames\n",
      "\t\t-- STATE_LIVE (sprites1-table-32-32.png)\n",
      "\t\t{\n";
for(my $a = 0; $a < 32; $a++)
{
   print "\t\t\t{";
   for(my $f = 0; $f < 8; $f++)
   {
      if( $f > 0 ) { print ", "; }
      print 256 + $a + $f * 32 + 1;
   }
   for(my $f = 8; $f < 16; $f++)
   {
      print ", ", 256 + $a + 1;
   }
   print "},\n";
}
print "\t\t}\n",
      "\t},\n";
# }}}

# {{{ Scissors frames.
print "\t-- KIND_SCISSORS\n",
      "\t{\n",
      "\t\t-- STATE_DYING (sprites2-table-64-64.png)\n",
      "\t\t{\n";
for(my $a = 0; $a < 32; $a++)
{
   print "\t\t\t{";
   for(my $f = 0; $f < 16; $f++)
   {
      if( $f > 0 ) { print ", "; }
      print int($a / 2) + int($f / 2) * 16 + 1;
   }
   for(my $f = 16; $f < DEATH_FRAMES; $f++)
   {
      print ", ", int($a / 2) + 7 * 16 + 1;
   }
   print "},\n";
}

print "\t\t},\n",
      "\t\t-- STATE_LIVE (sprites1-table-32-32.png)\n",
      "\t\t{\n";
for(my $a = 0; $a < 32; $a++)
{
   print "\t\t\t{";
   for(my $f = 7; $f >= 0; $f--)
   {
      print $a + $f * 32 + 1, ", ";
   }
   for(my $f = 1; $f < 8; $f++)
   {
      print $a + $f * 32 + 1, ", ";
   }
   print $a + 7 * 32 + 1, "},\n";
}

print "\t\t}\n",
      "\t},\n";
# }}}

# {{{ Light slime frames.
print "\t-- KIND_LIGHT_SLIME\n",
      "\t{\n",
      "\t\t-- STATE_DYING\n",
      "\t\t{},  -- Slime never dies.\n",
      "\t\t-- STATE_LIVE (sprites1-table-32-32.png)\n",
      "\t\t{\n";
for(my $a = 0; $a < 32; $a++)
{
   print "\t\t\t{";
   for(my $f = 0; $f < 8; $f++)
   {
      print 1536 + ($a % 16) + $f * 32 + 1, ", ";
   }
   for(my $f = 6; $f > 0; $f--)
   {
      print 1536 + ($a % 16) + $f * 32 + 1, ", ";
   }

   # The first frame for all angles should be identical because they are
   # clones, but due to error diffusion dithering, they come out slightly
   # different.  Here we make use of those differences to add a bit more
   # variety to what would have been just duplicated frames otherwise.
   # The end result is subtle, but because every frame is different, the
   # slimes will appear to have a bit of sparkle when they move.
   print 1536 + (($a + 1) % 16) + 1, ", ",
         1536 + (($a + 2) % 16) + 1, "},\n";
}
print "\t\t}\n",
      "\t},\n";
# }}}

# {{{ Dark slime frames.
print "\t-- KIND_DARK_SLIME\n",
      "\t{\n",
      "\t\t-- STATE_DYING\n",
      "\t\t{},  -- Slime never dies.\n",
      "\t\t-- STATE_LIVE (sprites1-table-32-32.png)\n",
      "\t\t{\n";
for(my $a = 0; $a < 32; $a++)
{
   print "\t\t\t{";
   for(my $f = 0; $f < 8; $f++)
   {
      print 1552 + ($a % 16) + $f * 32 + 1, ", ";
   }
   for(my $f = 6; $f >= 0; $f--)
   {
      print 1552 + ($a % 16) + $f * 32 + 1, ", ";
   }
   print 1552 + ($a % 16) + 1, "},\n";
}
print "\t\t}\n",
      "\t},\n";
# }}}

print "}\n";

# {{{ Extra paper frames.
print "paper_frames =  -- (sprites2-table-64-64.png)\n",
      "{\n";
for(my $this_a = 0; $this_a < 32; $this_a++)
{
   print "\t{\n";
   for(my $other_a = 0; $other_a < 32; $other_a++)
   {
      my $i0 = 128 + (($other_a & 15) >> 1) * 64;
      print "\t\t{";
      for(my $f = 0; $f < 4; $f++)
      {
         if( $f > 0 ) { print ", "; }
         my $d = $i0 + ((($this_a & 15) >> 1) * 2) + $f * 16 + 1;
         print "$d, $d";
      }
      for(my $f = 0; $f < 4; $f++)
      {
         my $d = $i0 + ((($this_a & 15) >> 1) * 2) + $f * 16 + 2;
         print ", $d, $d";
      }
      for(my $f = 16; $f < DEATH_FRAMES; $f++)
      {
         print ", ", $i0 + ((($this_a & 15) >> 1) * 2) + 3 * 16 + 2;
      }
      print "},  -- ($this_a, $other_a)\n";
   }
   print "\t},\n";
}
print "}\n";
# }}}
