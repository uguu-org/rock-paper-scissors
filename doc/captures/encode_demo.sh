#!/bin/bash
# Crop the relevant segment from input GIF such that it forms a complete
# loop that starts and ends on a blank screen, and reorder the segments
# to move that blank screen frame near the end of the loop.

exec ffmpeg \
   -ss 0:01.440 -to 0:43.200 -i playdate-20241006-223251.gif \
   -ss 0:00.930 -to 0:01.440 -i playdate-20241006-223251.gif \
   -filter_complex "[0:v:0][1:v:0]concat=n=2,scale=w=800:h=480:sws_flags=neighbor[outv]" \
   -map "[outv]" \
   -preset veryslow \
   -y demo.mp4
