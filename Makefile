# Toplevel Makefile for Rock Paper Scissors project.
#
# For debug builds:
#
#   make
#
# For release builds:
#
#   make release
#
# Only `pdc` from Playdate SDK is needed for these, plus a few standard
# command line tools.
#
# To refresh game data and build, do one of the following:
#
#   make -j refresh_data && make
#   make -j refresh_data && make release
#
# Refreshing game data requires a few more tools and libraries, see
# data/Makefile for more information.  At a minimum, you will likely need
# to edit data/svg_to_png.sh to set the correct path to Inkscape.

package_name=rock_paper_scissors
data_dir=data
source_dir=source
release_source_dir=release_source

# Debug build.
$(package_name).pdx/pdxinfo: \
	$(source_dir)/data.lua \
	$(source_dir)/main.lua \
	$(source_dir)/pdxinfo
	pdc $(source_dir) $(package_name).pdx

# Release build.
release: $(package_name).zip

$(package_name).zip:
	-rm -rf $(package_name).pdx $(release_source_dir) $@
	cp -R $(source_dir) $(release_source_dir)
	rm $(release_source_dir)/data.lua
	perl $(data_dir)/inline_data.pl $(source_dir)/data.lua $(source_dir)/main.lua | perl $(data_dir)/inline_constants.pl | perl $(data_dir)/strip_lua.pl > $(release_source_dir)/main.lua
	pdc -s $(release_source_dir) $(package_name).pdx
	zip -9 -r $@ $(package_name).pdx

# Refresh data files in source directory.
refresh_data:
	$(MAKE) -C $(data_dir)
	cp -f $(data_dir)/sprites1-table-32-32.png $(source_dir)/images/
	cp -f $(data_dir)/sprites2-table-64-64.png $(source_dir)/images/
	cp -f $(data_dir)/misc1-table-8-16.png $(source_dir)/images/
	cp -f $(data_dir)/misc2-table-16-16.png $(source_dir)/images/
	cp -f $(data_dir)/console-table-192-128.png $(source_dir)/images/
	cp -f $(data_dir)/text-table-176-16.png $(source_dir)/images/
	cp -f $(data_dir)/wall-table-8-8.png $(source_dir)/images/
	cp -f $(data_dir)/floor-table-64-64.png $(source_dir)/images/
	cp -f $(data_dir)/data.lua $(source_dir)/
	cp -f $(data_dir)/card0.png $(source_dir)/launcher/card.png
	cp -f $(data_dir)/card0.png $(source_dir)/launcher/card-highlighted/1.png
	cp -f $(data_dir)/card1.png $(source_dir)/launcher/card-highlighted/2.png
	cp -f $(data_dir)/card2.png $(source_dir)/launcher/card-highlighted/3.png
	cp -f $(data_dir)/card3.png $(source_dir)/launcher/card-highlighted/4.png
	cp -f $(data_dir)/card4.png $(source_dir)/launcher/card-highlighted/5.png
	cp -f $(data_dir)/card5.png $(source_dir)/launcher/card-highlighted/6.png
	cp -f $(data_dir)/card6.png $(source_dir)/launcher/card-highlighted/7.png
	cp -f $(data_dir)/card7.png $(source_dir)/launcher/card-highlighted/8.png
	cp -f $(data_dir)/card8.png $(source_dir)/launcher/card-highlighted/9.png
	cp -f $(data_dir)/card9.png $(source_dir)/launcher/card-highlighted/10.png
	cp -f $(data_dir)/card10.png $(source_dir)/launcher/card-highlighted/11.png
	cp -f $(data_dir)/card11.png $(source_dir)/launcher/card-highlighted/12.png
	cp -f $(data_dir)/card12.png $(source_dir)/launcher/card-highlighted/13.png
	cp -f $(data_dir)/card13.png $(source_dir)/launcher/card-highlighted/14.png
	cp -f $(data_dir)/card14.png $(source_dir)/launcher/card-highlighted/15.png
	cp -f $(data_dir)/card15.png $(source_dir)/launcher/card-highlighted/16.png
	cp -f $(data_dir)/launch0.png $(source_dir)/launcher/launchImage.png
	cp -f $(data_dir)/launch0.png $(source_dir)/launcher/launchImages/1.png
	cp -f $(data_dir)/launch1.png $(source_dir)/launcher/launchImages/2.png
	cp -f $(data_dir)/launch2.png $(source_dir)/launcher/launchImages/3.png
	cp -f $(data_dir)/launch3.png $(source_dir)/launcher/launchImages/4.png
	cp -f $(data_dir)/launch4.png $(source_dir)/launcher/launchImages/5.png
	cp -f $(data_dir)/launch5.png $(source_dir)/launcher/launchImages/6.png
	cp -f $(data_dir)/launch6.png $(source_dir)/launcher/launchImages/7.png
	cp -f $(data_dir)/launch7.png $(source_dir)/launcher/launchImages/8.png
	cp -f $(data_dir)/launch8.png $(source_dir)/launcher/launchImages/9.png
	cp -f $(data_dir)/launch9.png $(source_dir)/launcher/launchImages/10.png
	cp -f $(data_dir)/launch10.png $(source_dir)/launcher/launchImages/11.png
	cp -f $(data_dir)/launch11.png $(source_dir)/launcher/launchImages/12.png
	cp -f $(data_dir)/launch12.png $(source_dir)/launcher/launchImages/13.png
	cp -f $(data_dir)/launch13.png $(source_dir)/launcher/launchImages/14.png
	cp -f $(data_dir)/launch14.png $(source_dir)/launcher/launchImages/15.png
	cp -f $(data_dir)/launch15.png $(source_dir)/launcher/launchImages/16.png
	cp -f $(data_dir)/icon.png $(source_dir)/launcher/icon.png
	cp -f $(data_dir)/icon0.png $(source_dir)/launcher/icon-highlighted/1.png
	cp -f $(data_dir)/icon1.png $(source_dir)/launcher/icon-highlighted/2.png
	cp -f $(data_dir)/icon2.png $(source_dir)/launcher/icon-highlighted/3.png
	cp -f $(data_dir)/icon3.png $(source_dir)/launcher/icon-highlighted/4.png
	cp -f $(data_dir)/icon4.png $(source_dir)/launcher/icon-highlighted/5.png
	cp -f $(data_dir)/icon5.png $(source_dir)/launcher/icon-highlighted/6.png
	cp -f $(data_dir)/icon6.png $(source_dir)/launcher/icon-highlighted/7.png
	cp -f $(data_dir)/icon7.png $(source_dir)/launcher/icon-highlighted/8.png
	cp -f $(data_dir)/icon8.png $(source_dir)/launcher/icon-highlighted/9.png
	cp -f $(data_dir)/icon9.png $(source_dir)/launcher/icon-highlighted/10.png
	cp -f $(data_dir)/icon10.png $(source_dir)/launcher/icon-highlighted/11.png
	cp -f $(data_dir)/icon11.png $(source_dir)/launcher/icon-highlighted/12.png
	cp -f $(data_dir)/icon12.png $(source_dir)/launcher/icon-highlighted/13.png
	cp -f $(data_dir)/icon13.png $(source_dir)/launcher/icon-highlighted/14.png
	cp -f $(data_dir)/icon14.png $(source_dir)/launcher/icon-highlighted/15.png
	cp -f $(data_dir)/icon15.png $(source_dir)/launcher/icon-highlighted/16.png
	cp -f $(data_dir)/icon16.png $(source_dir)/launcher/icon-highlighted/17.png
	cp -f $(data_dir)/icon17.png $(source_dir)/launcher/icon-highlighted/18.png
	cp -f $(data_dir)/icon18.png $(source_dir)/launcher/icon-highlighted/19.png
	cp -f $(data_dir)/icon19.png $(source_dir)/launcher/icon-highlighted/20.png
	cp -f $(data_dir)/icon20.png $(source_dir)/launcher/icon-highlighted/21.png
	cp -f $(data_dir)/icon21.png $(source_dir)/launcher/icon-highlighted/22.png
	cp -f $(data_dir)/icon22.png $(source_dir)/launcher/icon-highlighted/23.png
	cp -f $(data_dir)/icon23.png $(source_dir)/launcher/icon-highlighted/24.png
	cp -f $(data_dir)/icon32.png $(source_dir)/launcher/icon-highlighted/25.png
	cp -f $(data_dir)/icon33.png $(source_dir)/launcher/icon-highlighted/26.png
	cp -f $(data_dir)/icon34.png $(source_dir)/launcher/icon-highlighted/27.png
	cp -f $(data_dir)/icon35.png $(source_dir)/launcher/icon-highlighted/28.png
	cp -f $(data_dir)/icon36.png $(source_dir)/launcher/icon-highlighted/29.png
	cp -f $(data_dir)/icon37.png $(source_dir)/launcher/icon-highlighted/30.png
	cp -f $(data_dir)/icon38.png $(source_dir)/launcher/icon-highlighted/31.png
	cp -f $(data_dir)/icon39.png $(source_dir)/launcher/icon-highlighted/32.png

clean:
	$(MAKE) -C $(data_dir) clean
	-rm -rf $(package_name).pdx $(package_name).zip $(release_source_dir)
