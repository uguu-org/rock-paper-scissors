# Build images and other supporting data.  Takes ~2 minutes to build and
# costs ~20M of disk space.
#
# Requires gcc, perl, netpbm, ImageMagick, and Inkscape.
# gcc also needs libpng, and perl needs libxml.
#
# See svg_to_png.sh for more details on Inkscape.

targets = \
	sprites1-table-32-32.png \
	sprites2-table-64-64.png \
	misc1-table-8-16.png \
	misc2-table-16-16.png \
	console-table-192-128.png \
	text-table-176-16.png \
	wall-table-8-8.png \
	floor-table-64-64.png \
	card0.png \
	card1.png \
	card2.png \
	card3.png \
	card4.png \
	card5.png \
	card6.png \
	card7.png \
	card8.png \
	card9.png \
	card10.png \
	card11.png \
	card12.png \
	card13.png \
	card14.png \
	card15.png \
	launch0.png \
	launch1.png \
	launch2.png \
	launch3.png \
	launch4.png \
	launch5.png \
	launch6.png \
	launch7.png \
	launch8.png \
	launch9.png \
	launch10.png \
	launch11.png \
	launch12.png \
	launch13.png \
	launch14.png \
	launch15.png \
	icon.png \
	icon0.png \
	icon1.png \
	icon2.png \
	icon3.png \
	icon4.png \
	icon5.png \
	icon6.png \
	icon7.png \
	icon8.png \
	icon9.png \
	icon10.png \
	icon11.png \
	icon12.png \
	icon13.png \
	icon14.png \
	icon15.png \
	icon16.png \
	icon17.png \
	icon18.png \
	icon19.png \
	icon20.png \
	icon21.png \
	icon22.png \
	icon23.png \
	icon32.png \
	icon33.png \
	icon34.png \
	icon35.png \
	icon36.png \
	icon37.png \
	icon38.png \
	icon39.png \
	data.lua

# Common compiler flags for C/C++ tools.
#
# "-march=native -O3" produces the fastest executables, although these flags
# are here mostly for readability.  For any particular executable, most of
# the time will be spent inside the pre-compiled libpng, and the overall
# build time will be dominated by Inkscape.
cflags = -march=native -O3 -Wall -Wextra -pedantic


# ......................................................................
# {{{ Primary build artefacts.

all: $(targets)

sprites1-table-32-32.png: t_sprites32.png optimize_png.pl
	perl optimize_png.pl $< > $@

sprites2-table-64-64.png: t_sprites64.png optimize_png.pl
	perl optimize_png.pl $< > $@

misc1-table-8-16.png: t_misc1_table.png optimize_png.pl
	perl optimize_png.pl $< > $@

misc2-table-16-16.png: t_misc2_table.png optimize_png.pl
	perl optimize_png.pl $< > $@

console-table-192-128.png: t_console_table.png optimize_png.pl
	perl optimize_png.pl $< > $@

text-table-176-16.png: t_text_table.png optimize_png.pl
	perl optimize_png.pl $< > $@

wall-table-8-8.png: generate_wall_tiles.exe optimize_png.pl
	./$< - | perl optimize_png.pl > $@

floor-table-64-64.png: t_floor_table.png optimize_png.pl
	perl optimize_png.pl $< > $@

data.lua: t_animation_frames.lua t_velocities.lua t_converge_angles.lua t_atan.lua
	cat $^ > $@

# }}}

# ......................................................................
# {{{ Launcher images.

# Card animation.
t_sprites_3x.png: t_gray_sprites_3x.png fs_dither.exe
	./fs_dither.exe $< $@

t_gray_sprites_3x.png: t_sprites.svg svg_to_png.sh
	./svg_to_png.sh $< $@ 0 0 32 1024 288

card0.png: t_sprites_3x.png optimize_png.pl
	convert -size 350x155 'xc:#ffffff' -depth 8 \
	"(" $< +repage -crop 96x96+0+1728 ")" -geometry +23+29 -composite \
	"(" $< +repage -crop 96x96+0+768 ")" -geometry +127+29 -composite \
	"(" $< +repage -crop 96x96+0+672 ")" -geometry +231+29 -composite \
	png:- | perl optimize_png.pl > $@

card1.png: t_sprites_3x.png optimize_png.pl
	convert -size 350x155 'xc:#ffffff' -depth 8 \
	"(" $< +repage -crop 96x96+0+1824 ")" -geometry +23+29 -composite \
	"(" $< +repage -crop 96x96+0+864 ")" -geometry +127+29 -composite \
	"(" $< +repage -crop 96x96+0+576 ")" -geometry +231+29 -composite \
	png:- | perl optimize_png.pl > $@

card2.png: t_sprites_3x.png optimize_png.pl
	convert -size 350x155 'xc:#ffffff' -depth 8 \
	"(" $< +repage -crop 96x96+0+1920 ")" -geometry +23+29 -composite \
	"(" $< +repage -crop 96x96+0+960 ")" -geometry +127+29 -composite \
	"(" $< +repage -crop 96x96+0+480 ")" -geometry +231+29 -composite \
	png:- | perl optimize_png.pl > $@

card3.png: t_sprites_3x.png optimize_png.pl
	convert -size 350x155 'xc:#ffffff' -depth 8 \
	"(" $< +repage -crop 96x96+0+2016 ")" -geometry +23+29 -composite \
	"(" $< +repage -crop 96x96+0+1056 ")" -geometry +127+29 -composite \
	"(" $< +repage -crop 96x96+0+384 ")" -geometry +231+29 -composite \
	png:- | perl optimize_png.pl > $@

card4.png: t_sprites_3x.png optimize_png.pl
	convert -size 350x155 'xc:#ffffff' -depth 8 \
	"(" $< +repage -crop 96x96+0+2112 ")" -geometry +23+29 -composite \
	"(" $< +repage -crop 96x96+0+1152 ")" -geometry +127+29 -composite \
	"(" $< +repage -crop 96x96+0+288 ")" -geometry +231+29 -composite \
	png:- | perl optimize_png.pl > $@

card5.png: t_sprites_3x.png optimize_png.pl
	convert -size 350x155 'xc:#ffffff' -depth 8 \
	"(" $< +repage -crop 96x96+0+2208 ")" -geometry +23+29 -composite \
	"(" $< +repage -crop 96x96+0+1248 ")" -geometry +127+29 -composite \
	"(" $< +repage -crop 96x96+0+192 ")" -geometry +231+29 -composite \
	png:- | perl optimize_png.pl > $@

card6.png: t_sprites_3x.png optimize_png.pl
	convert -size 350x155 'xc:#ffffff' -depth 8 \
	"(" $< +repage -crop 96x96+0+2304 ")" -geometry +23+29 -composite \
	"(" $< +repage -crop 96x96+0+1344 ")" -geometry +127+29 -composite \
	"(" $< +repage -crop 96x96+0+96 ")" -geometry +231+29 -composite \
	png:- | perl optimize_png.pl > $@

card7.png: t_sprites_3x.png optimize_png.pl
	convert -size 350x155 'xc:#ffffff' -depth 8 \
	"(" $< +repage -crop 96x96+0+2400 ")" -geometry +23+29 -composite \
	"(" $< +repage -crop 96x96+0+1440 ")" -geometry +127+29 -composite \
	"(" $< +repage -crop 96x96+0+0 ")" -geometry +231+29 -composite \
	png:- | perl optimize_png.pl > $@

card8.png: t_sprites_3x.png optimize_png.pl
	convert -size 350x155 'xc:#ffffff' -depth 8 \
	"(" $< +repage -crop 96x96+0+2496 ")" -geometry +23+29 -composite \
	"(" $< +repage -crop 96x96+0+768 ")" -geometry +127+29 -composite \
	"(" $< +repage -crop 96x96+0+96 ")" -geometry +231+29 -composite \
	png:- | perl optimize_png.pl > $@

card9.png: t_sprites_3x.png optimize_png.pl
	convert -size 350x155 'xc:#ffffff' -depth 8 \
	"(" $< +repage -crop 96x96+0+2592 ")" -geometry +23+29 -composite \
	"(" $< +repage -crop 96x96+0+768 ")" -geometry +127+29 -composite \
	"(" $< +repage -crop 96x96+0+192 ")" -geometry +231+29 -composite \
	png:- | perl optimize_png.pl > $@

card10.png: t_sprites_3x.png optimize_png.pl
	convert -size 350x155 'xc:#ffffff' -depth 8 \
	"(" $< +repage -crop 96x96+0+2688 ")" -geometry +23+29 -composite \
	"(" $< +repage -crop 96x96+0+768 ")" -geometry +127+29 -composite \
	"(" $< +repage -crop 96x96+0+288 ")" -geometry +231+29 -composite \
	png:- | perl optimize_png.pl > $@

card11.png: t_sprites_3x.png optimize_png.pl
	convert -size 350x155 'xc:#ffffff' -depth 8 \
	"(" $< +repage -crop 96x96+0+2784 ")" -geometry +23+29 -composite \
	"(" $< +repage -crop 96x96+0+768 ")" -geometry +127+29 -composite \
	"(" $< +repage -crop 96x96+0+384 ")" -geometry +231+29 -composite \
	png:- | perl optimize_png.pl > $@

card12.png: t_sprites_3x.png optimize_png.pl
	convert -size 350x155 'xc:#ffffff' -depth 8 \
	"(" $< +repage -crop 96x96+0+2880 ")" -geometry +23+29 -composite \
	"(" $< +repage -crop 96x96+0+768 ")" -geometry +127+29 -composite \
	"(" $< +repage -crop 96x96+0+480 ")" -geometry +231+29 -composite \
	png:- | perl optimize_png.pl > $@

card13.png: t_sprites_3x.png optimize_png.pl
	convert -size 350x155 'xc:#ffffff' -depth 8 \
	"(" $< +repage -crop 96x96+0+2976 ")" -geometry +23+29 -composite \
	"(" $< +repage -crop 96x96+0+768 ")" -geometry +127+29 -composite \
	"(" $< +repage -crop 96x96+0+576 ")" -geometry +231+29 -composite \
	png:- | perl optimize_png.pl > $@

card14.png: t_sprites_3x.png optimize_png.pl
	convert -size 350x155 'xc:#ffffff' -depth 8 \
	"(" $< +repage -crop 96x96+0+1536 ")" -geometry +23+29 -composite \
	"(" $< +repage -crop 96x96+0+768 ")" -geometry +127+29 -composite \
	"(" $< +repage -crop 96x96+0+672 ")" -geometry +231+29 -composite \
	png:- | perl optimize_png.pl > $@

card15.png: t_sprites_3x.png optimize_png.pl
	convert -size 350x155 'xc:#ffffff' -depth 8 \
	"(" $< +repage -crop 96x96+0+1632 ")" -geometry +23+29 -composite \
	"(" $< +repage -crop 96x96+0+768 ")" -geometry +127+29 -composite \
	"(" $< +repage -crop 96x96+0+672 ")" -geometry +231+29 -composite \
	png:- | perl optimize_png.pl > $@

# Icon animation.
#
# The target suffixes here do not covert a consecutive range, since we
# will be filling in duplicate frames using animation.txt.
icon.png: t_sprites.png optimize_png.pl
	convert $< +repage -crop 32x32+768+224 png:- | perl optimize_png.pl > $@

icon0.png: t_sprites.png optimize_png.pl
	convert $< +repage -crop 32x32+0+576 png:- | perl optimize_png.pl > $@

icon1.png: t_sprites.png optimize_png.pl
	convert $< +repage -crop 32x32+0+608 png:- | perl optimize_png.pl > $@

icon2.png: t_sprites.png optimize_png.pl
	convert $< +repage -crop 32x32+0+640 png:- | perl optimize_png.pl > $@

icon3.png: t_sprites.png optimize_png.pl
	convert $< +repage -crop 32x32+0+672 png:- | perl optimize_png.pl > $@

icon4.png: t_sprites.png optimize_png.pl
	convert $< +repage -crop 32x32+0+704 png:- | perl optimize_png.pl > $@

icon5.png: t_sprites.png optimize_png.pl
	convert $< +repage -crop 32x32+0+736 png:- | perl optimize_png.pl > $@

icon6.png: t_sprites.png optimize_png.pl
	convert $< +repage -crop 32x32+0+768 png:- | perl optimize_png.pl > $@

icon7.png: t_sprites.png optimize_png.pl
	convert $< +repage -crop 32x32+0+800 png:- | perl optimize_png.pl > $@

icon8.png: t_sprites.png optimize_png.pl
	convert $< +repage -crop 32x32+0+832 png:- | perl optimize_png.pl > $@

icon9.png: t_sprites.png optimize_png.pl
	convert $< +repage -crop 32x32+0+864 png:- | perl optimize_png.pl > $@

icon10.png: t_sprites.png optimize_png.pl
	convert $< +repage -crop 32x32+0+896 png:- | perl optimize_png.pl > $@

icon11.png: t_sprites.png optimize_png.pl
	convert $< +repage -crop 32x32+0+928 png:- | perl optimize_png.pl > $@

icon12.png: t_sprites.png optimize_png.pl
	convert $< +repage -crop 32x32+0+960 png:- | perl optimize_png.pl > $@

icon13.png: t_sprites.png optimize_png.pl
	convert $< +repage -crop 32x32+0+992 png:- | perl optimize_png.pl > $@

icon14.png: t_sprites.png optimize_png.pl
	convert $< +repage -crop 32x32+0+512 png:- | perl optimize_png.pl > $@

icon15.png: t_sprites.png optimize_png.pl
	convert $< +repage -crop 32x32+0+544 png:- | perl optimize_png.pl > $@

icon16.png: t_sprites.png optimize_png.pl
	convert $< +repage -crop 32x32+0+256 png:- | perl optimize_png.pl > $@

icon17.png: t_sprites.png optimize_png.pl
	convert $< +repage -crop 32x32+0+288 png:- | perl optimize_png.pl > $@

icon18.png: t_sprites.png optimize_png.pl
	convert $< +repage -crop 32x32+0+320 png:- | perl optimize_png.pl > $@

icon19.png: t_sprites.png optimize_png.pl
	convert $< +repage -crop 32x32+0+352 png:- | perl optimize_png.pl > $@

icon20.png: t_sprites.png optimize_png.pl
	convert $< +repage -crop 32x32+0+384 png:- | perl optimize_png.pl > $@

icon21.png: t_sprites.png optimize_png.pl
	convert $< +repage -crop 32x32+0+416 png:- | perl optimize_png.pl > $@

icon22.png: t_sprites.png optimize_png.pl
	convert $< +repage -crop 32x32+0+448 png:- | perl optimize_png.pl > $@

icon23.png: t_sprites.png optimize_png.pl
	convert $< +repage -crop 32x32+0+480 png:- | perl optimize_png.pl > $@

icon32.png: t_sprites.png optimize_png.pl
	convert $< +repage -crop 32x32+0+224 png:- | perl optimize_png.pl > $@

icon33.png: t_sprites.png optimize_png.pl
	convert $< +repage -crop 32x32+0+192 png:- | perl optimize_png.pl > $@

icon34.png: t_sprites.png optimize_png.pl
	convert $< +repage -crop 32x32+0+160 png:- | perl optimize_png.pl > $@

icon35.png: t_sprites.png optimize_png.pl
	convert $< +repage -crop 32x32+0+128 png:- | perl optimize_png.pl > $@

icon36.png: t_sprites.png optimize_png.pl
	convert $< +repage -crop 32x32+0+96 png:- | perl optimize_png.pl > $@

icon37.png: t_sprites.png optimize_png.pl
	convert $< +repage -crop 32x32+0+64 png:- | perl optimize_png.pl > $@

icon38.png: t_sprites.png optimize_png.pl
	convert $< +repage -crop 32x32+0+32 png:- | perl optimize_png.pl > $@

icon39.png: t_sprites.png optimize_png.pl
	convert $< +repage -crop 32x32+0+0 png:- | perl optimize_png.pl > $@

# Launcher animation.
t_title_text.png: t_gray_misc.png dither.exe
	convert $< +repage -crop 400x240+0+672 png:- | ./dither.exe - $@

launch0.png: card0.png t_title_text.png optimize_png.pl
	convert -size 400x240 'xc:#ffffff' -depth 8 $< -geometry +25+43 -composite t_title_text.png -composite png:- | perl optimize_png.pl > $@

launch1.png: card1.png t_title_text.png optimize_png.pl
	convert -size 400x240 'xc:#ffffff' -depth 8 $< -geometry +25+43 -composite t_title_text.png -composite png:- | perl optimize_png.pl > $@

launch2.png: card2.png t_title_text.png optimize_png.pl
	convert -size 400x240 'xc:#ffffff' -depth 8 $< -geometry +25+43 -composite t_title_text.png -composite png:- | perl optimize_png.pl > $@

launch3.png: card3.png t_title_text.png optimize_png.pl
	convert -size 400x240 'xc:#ffffff' -depth 8 $< -geometry +25+43 -composite t_title_text.png -composite png:- | perl optimize_png.pl > $@

launch4.png: card4.png t_title_text.png optimize_png.pl
	convert -size 400x240 'xc:#ffffff' -depth 8 $< -geometry +25+43 -composite t_title_text.png -composite png:- | perl optimize_png.pl > $@

launch5.png: card5.png t_title_text.png optimize_png.pl
	convert -size 400x240 'xc:#ffffff' -depth 8 $< -geometry +25+43 -composite t_title_text.png -composite png:- | perl optimize_png.pl > $@

launch6.png: card6.png t_title_text.png optimize_png.pl
	convert -size 400x240 'xc:#ffffff' -depth 8 $< -geometry +25+43 -composite t_title_text.png -composite png:- | perl optimize_png.pl > $@

launch7.png: card7.png t_title_text.png optimize_png.pl
	convert -size 400x240 'xc:#ffffff' -depth 8 $< -geometry +25+43 -composite t_title_text.png -composite png:- | perl optimize_png.pl > $@

launch8.png: card8.png t_title_text.png optimize_png.pl
	convert -size 400x240 'xc:#ffffff' -depth 8 $< -geometry +25+43 -composite t_title_text.png -composite png:- | perl optimize_png.pl > $@

launch9.png: card9.png t_title_text.png optimize_png.pl
	convert -size 400x240 'xc:#ffffff' -depth 8 $< -geometry +25+43 -composite t_title_text.png -composite png:- | perl optimize_png.pl > $@

launch10.png: card10.png t_title_text.png optimize_png.pl
	convert -size 400x240 'xc:#ffffff' -depth 8 $< -geometry +25+43 -composite t_title_text.png -composite png:- | perl optimize_png.pl > $@

launch11.png: card11.png t_title_text.png optimize_png.pl
	convert -size 400x240 'xc:#ffffff' -depth 8 $< -geometry +25+43 -composite t_title_text.png -composite png:- | perl optimize_png.pl > $@

launch12.png: card12.png t_title_text.png optimize_png.pl
	convert -size 400x240 'xc:#ffffff' -depth 8 $< -geometry +25+43 -composite t_title_text.png -composite png:- | perl optimize_png.pl > $@

launch13.png: card13.png t_title_text.png optimize_png.pl
	convert -size 400x240 'xc:#ffffff' -depth 8 $< -geometry +25+43 -composite t_title_text.png -composite png:- | perl optimize_png.pl > $@

launch14.png: card14.png t_title_text.png optimize_png.pl
	convert -size 400x240 'xc:#ffffff' -depth 8 $< -geometry +25+43 -composite t_title_text.png -composite png:- | perl optimize_png.pl > $@

launch15.png: card15.png t_title_text.png optimize_png.pl
	convert -size 400x240 'xc:#ffffff' -depth 8 $< -geometry +25+43 -composite t_title_text.png -composite png:- | perl optimize_png.pl > $@

# }}}

# ......................................................................
# {{{ Intermediate files.

# These are written to the current directory like everything else, but
# they mostly follow the naming convention of having a "t_" prefix, so
# it's easy to tell which files are transient.

# All object sprites.
t_sprites32.png: t_sprites.png
	convert $< +repage -crop 1024x1792+0+0 $@

t_sprites64.png: t_sprites.png
	convert $< +repage -crop 1024x2560+0+1792 $@

t_sprites.png: t_gray_sprites.png fs_dither.exe
	./fs_dither.exe $< $@

t_gray_sprites.png: t_sprites.svg svg_to_png.sh
	./svg_to_png.sh $< $@

t_sprites.svg: sprites.svg select_layers.pl remove_unused_defs.pl add_rocks.pl add_papers.pl
	perl select_layers.pl 'rocks|papers|scissors|slimes' t_gray_sprites.png $< | perl remove_unused_defs.pl | perl add_rocks.pl - | perl add_papers.pl - > $@

# Miscellaneous UI elements.
t_misc1_table.png: t_gray_misc.png dither.exe
	convert $< +repage -crop 160x16+0+0 png:- | ./dither.exe - $@

t_misc2_table.png: t_gray_misc.png dither.exe
	convert $< +repage -crop 176x16+160+0 png:- | ./dither.exe - $@

t_console_table.png: t_gray_misc.png dither.exe
	convert -size 1728x128 'xc:rgba(0,0,0,0)' \
	"(" $< +repage -crop 133x128+192+32 ")" -geometry +29+0 -composite \
	"(" $< +repage -crop 192x128+334+45 ")" -geometry +192+0 -composite \
	"(" $< +repage -crop 192x128+654+525 ")" -geometry +384+0 -composite \
	"(" $< +repage -crop 192x128+654+205 ")" -geometry +576+0 -composite \
	"(" $< +repage -crop 192x128+654+365 ")" -geometry +768+0 -composite \
	"(" $< +repage -crop 192x128+654+45 ")" -geometry +960+0 -composite \
	"(" $< +repage -crop 192x128+334+525 ")" -geometry +1152+0 -composite \
	"(" $< +repage -crop 192x128+334+205 ")" -geometry +1344+0 -composite \
	"(" $< +repage -crop 192x128+334+365 ")" -geometry +1536+0 -composite \
	png:- | ./dither.exe - $@

t_text_table.png: t_gray_misc.png dither.exe
	convert $< +repage -crop 176x304+0+16 png:- | ./dither.exe - $@

t_gray_misc.png: t_misc.svg svg_to_png.sh
	./svg_to_png.sh $< $@

t_misc.svg: misc.svg select_layers.pl remove_unused_defs.pl
	perl select_layers.pl '^ui.*' t_gray_misc.png $< | perl remove_unused_defs.pl > $@

# Floor tiles.
#
# We use ordered dithering (dither.exe) so that the Floyd-Steinberg
# dithered dead objects would stand out.  If we didn't want to
# highlight the dead objects, random dithering (random_dither.exe)
# would have been a suitable alternative.  We definitely don't want
# Floyd-Steinberg here because it makes the tile seams more visible.
t_floor_table.png: t_gray_floor.png crop_table.exe dither.exe
	./dither.exe $< - | ./crop_table.exe 128 128 64 64 32 32 > $@

# Undithered version of floor tiles, used for checking tile seams.
t_gray_floor_table.png: t_gray_floor.png crop_table.exe
	./crop_table.exe 128 128 64 64 32 32 < $< > $@

t_gray_floor.png: t_floor.svg svg_to_png.sh
	./svg_to_png.sh $< $@ 32 32 2080 2208

t_floor.svg: floor.svg select_layers.pl remove_unused_defs.pl
	perl select_layers.pl '^floor.*' t_gray_floor.png $< | perl remove_unused_defs.pl > $@

# Data tables.
t_animation_frames.lua: generate_animation_frames.pl
	perl $< > $@

t_velocities.lua: generate_velocities.pl
	perl $< > $@

t_converge_angles.lua: generate_converge_angles.pl
	perl $< > $@

t_atan.lua: generate_atan.pl
	perl $< > $@

# }}}

# ......................................................................
# {{{ Tools.

dither.exe: dither.c
	gcc $(cflags) $< -lpng -o $@

fs_dither.exe: fs_dither.c
	gcc $(cflags) $< -lpng -o $@

tile_dither.exe: tile_dither.c
	gcc $(cflags) $< -lpng -o $@

random_dither.exe: random_dither.c
	gcc $(cflags) $< -lpng -o $@

crop_table.exe: crop_table.c
	gcc $(cflags) $< -lpng -o $@

triangle_merge.exe: triangle_merge.c
	gcc $(cflags) $< -lpng -o $@

generate_wall_tiles.exe: generate_wall_tiles.c
	gcc $(cflags) $< -lpng -o $@

generate_test_wall_map.exe: generate_test_wall_map.c
	gcc $(cflags) $< -lpng -o $@

generate_test_floor_map.exe: generate_test_floor_map.c
	gcc $(cflags) $< -lpng -o $@

# }}}

# ......................................................................
# {{{ Tests and maintenance commands.

test: \
	test_passed.check_ref \
	test_passed.cleanup_styles \
	test_passed.crop_table \
	test_passed.dither \
	test_passed.element_count \
	test_passed.generate_build_graph \
	test_passed.inline_constants \
	test_passed.no_text_in_floors \
	test_passed.no_text_in_misc \
	test_passed.no_text_in_sprites \
	test_passed.select_layers \
	test_passed.strip_lua \
	test_passed.triangle_merge

test_passed.dither: dither.exe test_dither.sh
	./test_dither.sh $< && touch $@

test_passed.remove_unused_defs: remove_unused_defs.pl test_remove_unused_defs.sh
	./test_remove_unused_defs.sh $< && touch $@

test_passed.select_layers: select_layers.pl test_select_layers.sh
	./test_select_layers.sh $< && touch $@

test_passed.generate_build_graph: generate_build_graph.pl test_generate_build_graph.sh
	./test_generate_build_graph.sh $< && touch $@

test_passed.strip_lua: strip_lua.pl test_strip_lua.sh
	./test_strip_lua.sh $< && touch $@

test_passed.check_ref: check_ref.pl test_check_ref.sh
	./test_check_ref.sh $< && touch $@

test_passed.inline_constants: inline_constants.pl test_inline_constants.sh
	./test_inline_constants.sh $< && touch $@

test_passed.element_count: element_count.pl test_element_count.sh
	./test_element_count.sh $< && touch $@

test_passed.cleanup_styles: cleanup_styles.pl test_cleanup_styles.sh
	./test_cleanup_styles.sh $< && touch $@

test_passed.no_text_in_sprites: sprites.svg select_layers.pl element_count.pl
	! ( perl select_layers.pl 'rocks|papers|scissors|slimes' t_text_test.png $< | perl element_count.pl - | grep '^text' ) && touch $@

test_passed.no_text_in_misc: misc.svg select_layers.pl element_count.pl
	! ( perl select_layers.pl '^ui.*' t_text_test.png $< | perl element_count.pl - | grep '^text' ) && touch $@

test_passed.no_text_in_floors: floor.svg select_layers.pl element_count.pl
	! ( perl select_layers.pl '^floor.*' t_text_test.png $< | perl element_count.pl - | grep '^text' ) && touch $@

test_passed.crop_table: crop_table.exe test_crop_table.sh
	./test_crop_table.sh $< && touch $@

test_passed.triangle_merge: triangle_merge.exe test_triangle_merge.sh
	./test_triangle_merge.sh $< && touch $@

debug_wall_tiles: wall-table-8-8.png
	convert -size 128x72 'xc:#ffffff' $< -composite -scale '200%%' six:-

debug_floor_tiles: floor-table-64-64.png
	convert -size 1024x1024 'xc:#ffffff' $< -composite six:-

debug_test_wall: wall-table-8-8.png generate_test_wall_map.exe
	./generate_test_wall_map.exe $< - | convert png:- -scale '25%%' six:-

debug_test_floor: floor-table-64-64.png generate_test_floor_map.exe
	./generate_test_floor_map.exe $< - | convert png:- six:-

debug_test_gray_floor: t_gray_floor_table.png generate_test_floor_map.exe
	./generate_test_floor_map.exe $< - | convert png:- six:-

clean:
	-rm -f $(targets) *.exe *.o test_passed.* t_*

# }}}
