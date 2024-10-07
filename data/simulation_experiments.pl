#!/usr/bin/perl -w
# This script collects various results from simulate_game() runs.
#
# The raw data is in simulation_experiments.log

use strict;
use File::Spec;
use constant LOG_FILE_NAME => "simulation_experiments.log";

my @times = ();
my $rock_wins = 0;
my $paper_wins = 0;
my $scissors_wins = 0;
my $start_clock = 0;
my $end_clock = 0;

sub output_stats()
{
   my $run_count = scalar @times;
   return if $run_count == 0;

   my $total = 0;
   foreach my $t (@times)
   {
      $total += $t;
   }
   my $average = $total / $run_count;
   my $d = 0;
   foreach my $t (@times)
   {
      $d += ($t - $average) * ($t - $average);
   }
   @times = sort {$a <=> $b} @times;
   my $min = $times[0];
   my $max = $times[$#times];
   my $median = $times[int((scalar @times) / 2)];

   $d = sqrt($d / $run_count);
   print "total steps = $total\n",
         "average steps = $total / $run_count = $average\n",
         "min steps = $min\n",
         "max steps = $max\n",
         "median steps = $median\n",
         "standard deviation = $d\n",
         "rock wins = $rock_wins\n",
         "paper wins = $paper_wins\n",
         "scissors wins = $scissors_wins\n",
         "simulation time = ", $end_clock - $start_clock, "\n";
}

my $log_file_name;
if( $#ARGV < 0 )
{
   my ($vol, $dir, $file) = File::Spec->splitpath($0);
   $log_file_name = $dir . LOG_FILE_NAME;
}
else
{
   $log_file_name = $ARGV[0];
}

open my $infile, "<$log_file_name" or die "Failed to open $log_file_name: $!";
while( my $line = <$infile> )
{
   next if $line =~ /^#/;
   if( $line =~ /^\[(\d+(?:\.\d*)?)\]: / )
   {
      if( $start_clock > 0 )
      {
         $end_clock = $1;
      }
      else
      {
         $start_clock = $end_clock = $1;
      }

      # Debug log lines include experiment results.
      if( $line =~ /rock wins, steps = (\d+)/ )
      {
         push @times, $1;
         $rock_wins++;
      }
      elsif( $line =~ /paper wins, steps = (\d+)/ )
      {
         push @times, $1;
         $paper_wins++;
      }
      elsif( $line =~ /scissors wins, steps = (\d+)/ )
      {
         push @times, $1;
         $scissors_wins++;
      }
   }
   else
   {
      # Non-debug log lines delineate different experiments.

      # Output stats from previous experiment.
      output_stats();

      # Output header for next experiment.
      print $line;

      # Reset stats for next experiment.
      @times = ();
      $rock_wins = 0;
      $paper_wins = 0;
      $scissors_wins = 0;
      $start_clock = $end_clock = 0;
   }
}

# Output stats from final experiment.
output_stats();
