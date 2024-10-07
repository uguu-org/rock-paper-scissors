--[[ Rock paper scissors

--]]

import "CoreLibs/graphics"
import "CoreLibs/ui"
import "data"

----------------------------------------------------------------------
--{{{ Debug functions.

-- Print a message, and return true.  The returning true part allows this
-- function to be called inside assert(), which means this function will
-- be stripped in the release build by strip_lua.pl.
local function debug_log(msg)
	print(string.format("[%f]: %s", playdate.getElapsedTime(), msg))
	return true
end

-- Log an initial message on startup, and another one later when the
-- initialization is done.  This is for measuring startup time.
local random_seed = playdate.getSecondsSinceEpoch()
local title_version <const> = playdate.metadata.name .. " v" .. playdate.metadata.version
assert(debug_log(title_version .. " (debug build), random seed = " .. random_seed))
math.randomseed(random_seed)

-- Draw frame rate in debug builds.
local function debug_frame_rate()
	playdate.drawFPS(24, 220)
	return true
end

-- Reset all debug counters.
local function debug_count_reset()
	global_debug_count_same_cell = 0
	global_debug_count_no_collision = 0
	global_debug_count_collision = 0
	return true
end

-- Increment debug counter.
local function debug_count_same_cell()
	global_debug_count_same_cell += 1
	return true
end
local function debug_count_collision()
	global_debug_count_collision += 1
	return true
end
local function debug_count_no_collision()
	global_debug_count_no_collision += 1
	return true
end

-- Log debug counters.
local function debug_count_report()
	return debug_log("same_cell=" .. global_debug_count_same_cell ..
	                 ", no_collision=" .. global_debug_count_no_collision ..
	                 ", collision=" .. global_debug_count_collision)
end

--}}}

----------------------------------------------------------------------
--{{{ Game data.

-- Constants.
local gfx <const> = playdate.graphics
local abs <const> = math.abs
local floor <const> = math.floor
local rand <const> = math.random

-- Object enumerations.
local KIND_ROCK <const> = 1
local KIND_PAPER <const> = 2
local KIND_SCISSORS <const> = 3
local KIND_LIGHT_SLIME <const> = 4
local KIND_DARK_SLIME <const> = 5
local STATE_DEAD <const> = 0
local STATE_DYING <const> = 1
local STATE_LIVE <const> = 2

-- Width and height of the playable area in pixels.
local WORLD_SIZE <const> = 1280
assert((WORLD_SIZE & 7) == 0)

-- Padding in pixels.  We pad all borders so that wall tiles will cover all
-- visible pixels even when we are following some object at the edge of the
-- game area.
--
-- One full screen worth of pixels on each side would be more than sufficient,
-- but we also want to minimize the amount of padding since they affect game
-- startup times.
local HORIZONTAL_PADDING <const> = (400 // 2) + 32
local VERTICAL_PADDING <const> = (240 // 2) + 32
assert((HORIZONTAL_PADDING & 7) == 0)
assert((VERTICAL_PADDING & 7) == 0)

-- Number of objects for each of the rock+paper+scissors groups.
--
-- A really large population will eat up all available frame rates because
-- simulating that population is expensive, although it sort of doesn't
-- matter since the initial population tend to get killed off quickly.
-- Still, a large initial population will require a larger world to hold
-- all objects, and that makes the later part of the game feel more sparse.
-- Current setting feels like the best balance with respect to frame rate
-- and world size.
--
-- By the way, the cost of running a large population is mostly in simulating
-- the movement logic.  Playdate seems fairly capable in drawing a large
-- number of sprites, and we have not found that to be a bottleneck.
local POPULATION_COUNT <const> = 99
assert(POPULATION_COUNT * 64 * 64 < WORLD_SIZE * WORLD_SIZE)

-- Total number of objects being simulated.
--
-- First POPULATION_COUNT*3 objects are rocks/papers/scissors, remaining
-- objects are slimes.  Slimes are basically indestructible moving obstacles.
local OBJECT_COUNT <const> = POPULATION_COUNT * 3 + 16
assert(OBJECT_COUNT >= POPULATION_COUNT * 3)
assert(OBJECT_COUNT * 32 * 32 < WORLD_SIZE * WORLD_SIZE)

-- Accelerometer settings.
--
-- See also accelerometer_dx and accelerometer_dy.
local ACCELEROMETER_DEADZONE <const> = 0.05
local ACCELEROMETER_MAX_TILT <const> = 0.25
local ACCELEROMETER_MAX_VELOCITY <const> = average_velocity[1][1] * 2

-- Collision table dimensions.  Each collision table cell corresponds to an
-- 8x8 area, so we would shift right 3 bits to convert from screen coordinates
-- to collision table coordinates.
--
-- Collision table is padded with an extra screen worth of pixels on all sides.
-- The extra pixels will be covered by solid wall tiles.
local COLLISION_TABLE_WIDTH <const> = (WORLD_SIZE + HORIZONTAL_PADDING * 2) >> 3
local COLLISION_TABLE_HEIGHT <const> = (WORLD_SIZE + VERTICAL_PADDING * 2) >> 3

-- Floor tile table dimensions.  Each floor cell corresponds to a 64x64
-- area, so conversion from collision coordinates to floor tile coordinates
-- involves shifting right 3 more bits.
--
-- The dimensions are padded with 2 extra tiles: one to account for collision
-- table not being a multiple of 8, the other to account for random shifts,
-- see comments near floor_shift_x and floor_shift_y.
local FLOOR_TABLE_WIDTH <const> = (COLLISION_TABLE_WIDTH >> 3) + 2
local FLOOR_TABLE_HEIGHT <const> = (COLLISION_TABLE_HEIGHT >> 3) + 2

-- Collision table indices.
local GAME_AREA_MIN_X <const> = HORIZONTAL_PADDING >> 3
local GAME_AREA_MAX_X <const> = (HORIZONTAL_PADDING + WORLD_SIZE) >> 3
local GAME_AREA_MIN_Y <const> = VERTICAL_PADDING >> 3
local GAME_AREA_MAX_Y <const> = (VERTICAL_PADDING + WORLD_SIZE) >> 3

-- Number of frames for holding "up" or "right" to enter input tests.
local INPUT_TEST_TIMER <const> = 90

-- Image tables.
local sprites32 <const> = gfx.imagetable.new("images/sprites1")
local sprites64 <const> = gfx.imagetable.new("images/sprites2")
local misc1_images <const> = gfx.imagetable.new("images/misc1")
local misc2_images <const> = gfx.imagetable.new("images/misc2")
local console_images <const> = gfx.imagetable.new("images/console")
local text_images <const> = gfx.imagetable.new("images/text")
local wall_images <const> = gfx.imagetable.new("images/wall")
local floor_images <const> = gfx.imagetable.new("images/floor")
assert(sprites32)
assert(sprites64)
assert(misc1_images)
assert(misc2_images)
assert(console_images)
assert(text_images)
assert(wall_images)
assert(floor_images)

-- All moving objects in a single array.
local obj_table = table.create(OBJECT_COUNT, 0)
for i = 1, OBJECT_COUNT do
	obj_table[i] =
	{
		-- Object kind, in the range of [1..5].
		--
		-- Note that rock/paper/scissors objects are evenly distributed within
		-- the first range.  The second range is evenly divided among light
		-- and dark slimes.
		--
		-- Also note that this is the only field that's pre-initialized,
		-- since it will remain constant for the whole game.  The other
		-- fields are set to zero here, but will be updated to nonzero
		-- values in init_world().
		kind = (i <= POPULATION_COUNT * 3 and (i - 1) % 3 + 1) or
		       (KIND_LIGHT_SLIME + (i & 1)),

		-- Object live/dead state.
		state = 0,

		-- Current animation frame.
		-- STATE_DEAD -> 24
		-- STATE_DYING -> [1..24]
		-- STATE_LIVE -> [1..16]
		frame = 0,

		-- World position for the center of this object, with these ranges:
		-- (GAME_AREA_MIN_X << 8) <= x < (GAME_AREA_MAX_X << 8)
		-- (GAME_AREA_MIN_Y << 8) <= y < (GAME_AREA_MAX_Y << 8)
		--
		-- We use a fixed-point coordinate system, storing the fractional
		-- part in the lower 8 bits.  We need at least ~5 bits to capture
		-- enough difference in velocities for the 32 rotation angles we
		-- use, but since we don't use that many high bits, we will bump
		-- the precision up to 8 for byte alignment.
		--
		-- The reason why we use a fixed-point coordinate system is to avoid
		-- unexpected behavior with floating points, since we got burned by
		-- that a few times with Magero.  Benchmarks shows that fixed-point
		-- arithmetic is sometimes slightly faster than floating point, so
		-- that's also nice.
		--
		-- The range is padded with one extra screen's worth of pixels.
		-- We only need 32 extra pixels if we just want to simplify bounds
		-- checking, but we add an extra screen worth of padding to account
		-- for boundary pixels used by the background layer.
		x = 0,
		y = 0,

		-- Current movement direction, in the range of [1..32].
		--
		-- 32 seems like sufficient granularity in number of angle steps, and
		-- also provides a good balance in terms of number of sprites.
		a = 0,

		-- Target movement direction, in the range of [1..32].
		ta = 0,

		-- Direction of the object that killed the current object,
		-- in the range of [1..32].
		ka = 0,

		-- Number of frames where current object remains stunned.  A stunned
		-- object can only turn (update direction), and can not move (update
		-- position) until stun counter reaches zero.
		--
		-- Auto-controlled objects will become stunned for a few frames after
		-- a collision.  This saves a bit of CPU processing time because it
		-- allows the object to turn on the spot, instead of immediately running
		-- into the same obstacle again and incur another collision.
		--
		-- Player controlled objects will never become stunned.  It's not
		-- that collisions here are any cheaper, we are just more generous
		-- with players.
		stun = 0,
	}
end
assert(obj_table[KIND_ROCK].kind == KIND_ROCK)
assert(obj_table[KIND_PAPER].kind == KIND_PAPER)
assert(obj_table[KIND_SCISSORS].kind == KIND_SCISSORS)

-- Number of live objects remaining for each kind.
local live_count = {0, 0, 0}

-- Number of live objects at the start of each game, set by population_test().
local population_limit = {POPULATION_COUNT, POPULATION_COUNT, POPULATION_COUNT}

-- Number of simulation steps completed.
--
-- This is used for adjusting action_frame_mask, see run_simulation_step.
local game_steps = 0

-- Granularity for recomputing object directions, accepted values are
-- {15, 7, 3, 1}.  This is applied to frame counters for each individual
-- object, and objects only recompute their target angles when the masked
-- bits are zero.
--
-- When the game initially starts, all objects will recompute target angles
-- once every 16 frames.  This decreases their accuracy in following victims,
-- and also reduces the amount of CPU cycles needed to recompute directions,
-- both of which are preferred at the beginning of the game.  When game has
-- progressed for a while, most of the objects would have already died out,
-- and we have the extra CPU cycles needed to compute angles at every frame,
-- so we gradually increase the computation accuracy to make sure that the
-- endgame does not drag on due to excessive overshooting.
local action_frame_mask = 15

-- Tilemap showing number of live objects remaining.
local status_box = gfx.tilemap.new()
status_box:setImageTable(misc1_images)

-- Cell occupancy status.  Indices are [screen_y >> 3][screen_x >> 3],
-- or [world_y >> 11][world_x >> 11].  Note that this indexing scheme
-- does not contain any "+1", despite Lua's tables being 1-based.  This
-- is because we constrained the objects' coordinates to avoid the
-- zeroth row and column.
--
-- Each entry contains one of the following:
--  0 = cell is empty.
--  -1 = cell is a permanent obstacle.
--  other = cell contains an index into obj_table.
--
-- Collision table cells are 8 pixels wide to match the size of the wall
-- tiles.  Each object actually occupies 4 cells (a 16x16 pixel square),
-- so collision detection works by marking and unmarking in 4-cell groups.
--
-- It would have been cheaper if each object occupies exactly one collision
-- cell (with larger collision cells to match object size), but then the
-- collision grid would be more apparent.  Current scheme with 4 cells per
-- object is cumbersome and not 100% accurate, but it's still cheaper and
-- simpler than maintaining trees of bounding boxes, and we managed to get
-- a reasonable frame rate with it by optimizing update_obj().
--
-- collision_table is a table of tables, which is the natural way for storing
-- 2D data.  But we have also tried making it just single flat table and
-- do the indexing manually ("collision_table[(y << 8) | x]").  Benchmark
-- result showed no discernible difference, so it didn't seem to be worth
-- the readability tradeoff.
local collision_table = table.create(COLLISION_TABLE_HEIGHT, 0)

-- Scratch tables, used by init_walls_and_floors.
local scratch_table =
{
	table.create(COLLISION_TABLE_HEIGHT, 0),
	table.create(COLLISION_TABLE_HEIGHT, 0),
}

-- Preallocate collision_table and scratch_table rows, and also populate
-- some scratch_table edge entries.  scratch_table edges will not be
-- modified after these loops.
for y = 1, COLLISION_TABLE_HEIGHT do
	collision_table[y] = table.create(COLLISION_TABLE_WIDTH, 0)
	for i = 1, 2 do
		scratch_table[i][y] = table.create(COLLISION_TABLE_WIDTH, 0)
		scratch_table[i][y][1] = 1
		scratch_table[i][y][COLLISION_TABLE_WIDTH] = 1
	end
end
for i = 1, 2 do
	for x = 1, COLLISION_TABLE_WIDTH do
		scratch_table[i][1][x] = 1
		scratch_table[i][COLLISION_TABLE_HEIGHT][x] = 1
	end
end

-- Background tiles.
local wall_tiles = table.create(COLLISION_TABLE_WIDTH * COLLISION_TABLE_HEIGHT, 0)
local wall_tilemap = gfx.tilemap.new()
wall_tilemap:setImageTable(wall_images)

local floor_tiles = table.create(FLOOR_TABLE_WIDTH * FLOOR_TABLE_HEIGHT, 0)
local floor_tilemap = gfx.tilemap.new()
floor_tilemap:setImageTable(floor_images)

-- Offsets for shifting floor tiles.  Since floor tiles don't need to be
-- aligned to anything, we apply some random shifts at the beginning of
-- each game so that floor tiles and wall tiles are slightly offset from
-- each other.
local floor_shift_x = 0
local floor_shift_y = 0

-- Upper left corner of a 6x6 area for triggering respawns, in collision_table
-- coordinates (pixels >> 3, or world coordinates >> 11).
--
-- Landing in this area will cause extinct victims to respawn.  For example,
-- if all rocks are dead and a paper lands touches one of these tiles, at most
-- one rock will respawn somewhere on the map outside of the currently visible
-- area.  But if all rocks are dead and a scissors touches the same square,
-- nothing happens.
--
-- This is meant to solve the problem where if there are only two kinds
-- of objects remaining, one of them will be hopelessly pursued by the other
-- with no chance of winning.  By allowing the extinct third kind to respawn,
-- the victim now has a chance to perturb the power imbalance -- they just
-- need to find the one special floor tile on the map to trigger the respawn,
-- and then outrun their killers for long enough before killing off the
-- newly respawned object.
--
-- This is mostly a player orientated feature, since auto-controlled objects
-- do not actively seek out the special floor tile, and they will try to kill
-- off the newly respawned object immediately anyways.
--
-- The fact that auto-controlled objects always try to kill off the last
-- victim is more or less why we needed this feature in the first part.
-- Strategically, an easier way to win is to avoid killing victims until all
-- threats are gone.  But since player can not control every object, this
-- sort of turn into a game of luck in seeing what the other non-player
-- controlled objects will do.  In effect, it becomes a spectator game with
-- 98 objects of a particular kind instead of 99 objects.  With this respawn
-- feature, player can take matters into their own hands when auto-controlled
-- objects were overzealous in their killings.
local respawn_x = 0
local respawn_y = 0

-- List of world coordinates that serves as initial object positions.
--
-- These initial positions are placed at 64 pixel intervals (8 cells).
-- Since objects have hit boxes of 16 pixels, so there are at least 48 pixels
-- of space between any two initial positions.  Thus, there should always be
-- room available for navigating around objects regardless of where we place
-- them.
--
-- This 48 pixel gap is also meant to prevent instant death after starting
-- the game, but that's less of a guarantee.  Usually half of all objects will
-- be killed in the first 10 seconds (average game lasts about a minute).
local world_positions = table.create((WORLD_SIZE // 64) * (WORLD_SIZE // 64), 0)
local function init_world_positions()
	local i = 1
	for y = GAME_AREA_MIN_Y + 3, GAME_AREA_MAX_Y - 3, 16 do
		-- X positions are staggered every other row to increase initial
		-- distance, e.g.:
		--  1   2   3
		--    4   5   6
		--  7   8   9
		--    ...
		for x = GAME_AREA_MIN_X + 3, GAME_AREA_MAX_X - 3, 8 do
			world_positions[i] = {x << 11, y << 11}
			i += 1
		end
		for x = GAME_AREA_MIN_X + 7, GAME_AREA_MAX_X - 3, 8 do
			world_positions[i] = {x << 11, (y + 8) << 11}
			i += 1
		end
	end
	assert(i <= (WORLD_SIZE // 64) * (WORLD_SIZE // 64))
end
init_world_positions()
assert(#world_positions >= OBJECT_COUNT)

-- Center of current visible viewport, in world coordinates.
local view_world_x = 0
local view_world_y = 0

-- Center of current visible viewport, in screen coordinates.  This is
-- updated by update_view for testing sprite visibility and drawing the
-- actual sprites, and cached here so that we don't need to compute this
-- repeatedly.
local view_x = 0
local view_y = 0

-- Player object kind, or 0 if player is just watching.
local player_kind = 0

-- Index of the object we are currently following.
--
-- If player_kind is nonzero, this is also the object that's currently
-- under player control.
--
-- Player controls at most one object.  In early designs, there were some
-- thoughts on having some mode to control multiple objects at once, but that
-- adds a fair bit of complexity.  Instead of building a system that would
-- make manual control of multiple objects effective, we would rather take
-- features from such a system and fold them into automatic controls.
local follow_index = 1

-- Current game state, a reference to one of the game_*() functions.
local game_state = nil

-- Coroutine for initializing world.
--
-- Initializing the world takes over 5 seconds if we do it synchronously,
-- and we don't want players to wait for a loading screen.  Instead, we
-- always try to initialize the next game while the current game is still
-- in progress, using whatever spare cycles we got at the end of each frame.
local init_world_thread = nil

-- Progress counter for init_world.
--
-- We need to wait for init_world to complete before a new game can be
-- started, and this counter is used to report progress.  When initialization
-- is done, this counter would have reached MAX_INIT_PROGRESS, defined below.
local init_progress = 0

-- Maximum number of initialization steps needed by init_world.
local MAX_INIT_PROGRESS <const> =
	1 +                                  -- Shuffle world_positions.
	COLLISION_TABLE_HEIGHT // 4 +        -- Populate random cells.
	COLLISION_TABLE_HEIGHT - 2 +         -- Smooth random cells.
	COLLISION_TABLE_HEIGHT // 4 +        -- Fill borders.
	1 +                                  -- Create holes for initial positions.
	COLLISION_TABLE_HEIGHT // 4 +        -- Convert scratch_table bits.
	FLOOR_TABLE_HEIGHT // 4 +            -- Initialize floor tiles.
	(COLLISION_TABLE_HEIGHT - 2) // 4 +  -- Initialize wall tiles.
	1 +                                  -- Populate collision_table.
	32 +                                 -- Set wall tiles.
	32 +                                 -- Set floor tiles.
	1                                    -- Initialize objects.

-- True if game is no longer in progress.
--
-- Because init_world takes so long, we will start initializing the next
-- game as soon the current game gets sparse.  But we can only do so much
-- while the current game is in progress since the current game data is
-- still in use.  The last pieces to update are the tilemaps, which we
-- will hold off on updating until this flag becomes false.
local game_in_progress = false

-- Initial timestamp at the start of each frame.  This is for budgeting
-- how much time we can spend inside init_world_thread.
local frame_start_time = nil

-- Pause screen image.
local menu_image = nil

-- Accelerometer calibration settings.
--
-- The default is zero, meaning the device must be held at a level orientation
-- for rocks to stand still.  This might not be the most ergonomic orientation,
-- so we added a menu option for players to reset the zero orientation.
--
-- One possible alternative to initializing with zeroes is to read the
-- accelerometer on startup, and assume the initial orientation to be the
-- desired zero orientation.  This provides the convenience of not having to
-- calibrate the accelerometer every time, but ruins the perfect zero
-- orientation.  We provide this reset-zero-orientation function for
-- convenience, but the preferred way to play is to hold the device physically
-- level, since that's where the accelerometer is most sensitive.
local accelerometer_dx = 0
local accelerometer_dy = 0
local accelerometer_dz = 0

-- Next game countdown timer, used to determine when to start the next game
-- in spectator mode after reaching game_completed state.
local next_game_countdown_frames = 0

-- Animation frame indices for game_select() state, in the range of [0..255].
-- game_select_frame[1] = instruction image frame.
-- game_select_frame[2] = rock frame.
-- game_select_frame[3] = paper frame.
-- game_select_frame[4] = scissors frame.
local game_select_frame = {0, 0, 0, 0}

-- Rotated console image for game_select() state.
local game_select_rotated_console = nil

-- Scratch image buffer for game_select() state.
local game_select_scratch = nil

-- Timer for entering accelerometer test.  See accelerometer_test() function.
local accelerometer_test_timer = 0

-- Timer for entering crank test.  See crank_test() function.
local crank_test_timer = 0

-- Timer for entering population test.  See population_test() function.
local population_test_timer = 0

-- Direction of example objects set by accelerometer_test() and crank_test(),
-- in the range of [1..32].
local example_direction = 1

-- True if reset menu option is selected.
--
-- This is needed to break out of the coroutines in game_init() state.
local reset_requested = false

-- Start game with accelerometer enabled.  This is so that if player tries
-- to calibrate accelerometer when entering game_select() for the first time,
-- the accelerometer would return useful values instead of all zeroes.
--
-- If player end up not using the accelerometer, we will just stop reading
-- it when the first game is started.
playdate.startAccelerometer()

-- Use white background by default.
gfx.setBackgroundColor(gfx.kColorWhite)

--}}}

----------------------------------------------------------------------
--{{{ Game functions.

-- Count number of object kinds that are still surviving.
local function live_kind_count()
	return ((live_count[KIND_ROCK] ~= 0 and 1) or 0) +
	       ((live_count[KIND_PAPER] ~= 0 and 1) or 0) +
	       ((live_count[KIND_SCISSORS] ~= 0 and 1) or 0)
end

-- Given a world coordinate, overwrite content of the 4 cells near that
-- coordinate.
local function set_occupant(x, y, occupant)
	-- Cell index computation is equivalent to:
	-- cell_x = ((x >> 8) + 4) >> 3
	--
	-- ">>8" converts from fixed-point world coordinates to screen coordinates
	-- by dropping the lower 8 bits.
	--
	-- "+4" adds rounding for the next step.
	--
	-- ">>3" converts from screen coordinates to collision_table coordinates
	-- by dropping the lower 3 bits.
	local cell_x <const> = (x + 0x400) >> 11
	local cell_y <const> = (y + 0x400) >> 11
	collision_table[cell_y][cell_x] = occupant
	collision_table[cell_y][cell_x + 1] = occupant
	collision_table[cell_y + 1][cell_x] = occupant
	collision_table[cell_y + 1][cell_x + 1] = occupant
end

-- Given a world coordinate, return the contents of the 4 existing cells
-- near that coordinate.
local function get_occupants(x, y)
	local cell_x <const> = (x + 0x400) >> 11
	local cell_y <const> = (y + 0x400) >> 11
	return collision_table[cell_y][cell_x],
	       collision_table[cell_y][cell_x + 1],
	       collision_table[cell_y + 1][cell_x],
	       collision_table[cell_y + 1][cell_x + 1]
end

-- Check that all 4 cells in the collision table contains expected index.
local function has_expected_occupant(x, y, expected)
	local a <const>, b <const>, c <const>, d <const> = get_occupants(x, y)
	return a == expected and b == expected and c == expected and d == expected
end

-- Check if a particular spot is available for placing new objects.
local function is_empty(x, y)
	return has_expected_occupant(x, y, 0)
end

-- Syntactic sugar, force a particular edge bit to be set on a floor tile.
local function set_floor_edge_bit(index, bitmask)
	floor_tiles[index] = ((floor_tiles[index] - 1) | bitmask) + 1
end

-- Mark location of the special respawn tiles in debug builds.  This is used
-- for checking alignment with collision_table.
local function debug_respawn_tile_location()
	for y = 0, 5 do
		for x = 0, 5 do
			wall_tiles[(respawn_y + y) * COLLISION_TABLE_WIDTH + (respawn_x + x) + 1] = 0x83
		end
	end
	return true
end

-- Mark location where a respawn happened.  This is used to check
-- object selection.
local function debug_mark_respawned_spot(cell_x, cell_y)
	wall_tilemap:setTileAtPosition(cell_x,     cell_y,     0x82)
	wall_tilemap:setTileAtPosition(cell_x + 1, cell_y,     0x82)
	wall_tilemap:setTileAtPosition(cell_x,     cell_y + 1, 0x82)
	wall_tilemap:setTileAtPosition(cell_x + 1, cell_y + 1, 0x82)
	return true
end

-- Initialize tilemaps and collision_table.
--
-- The function name refers to the two main tilemaps used by the game.
--
-- + Walls match up with collision_table, and adds extra wrinkles to what
--   would otherwise be just a large empty space.  We need walls because it
--   would be difficult to corner victims otherwise, and the game would drag
--   on for a long time.
--
-- + Floors are mostly decorative, except that one area that enables respawns.
local function init_walls_and_floors()
	-- Populate all cells with random values.
	--
	-- This loop and the next loop implements the cave generation algorithm
	-- described here:
	-- https://www.roguebasin.com/index.php/Cellular_Automata_Method_for_Generating_Random_Cave-Like_Levels
	--
	-- We use an initial wall density ratio of 0.45, same as what's suggested
	-- in the page above.  A ratio above 0.45 will cause the map to converge
	-- toward being mostly filled due to the smoothing step.  Similarly a ratio
	-- below 0.45 will cause the map to be mostly empty.  So 0.45 really is
	-- the sweet spot.
	--
	-- If we want to pick a different ratio: a mostly filled map will turn
	-- this into a digging game, which might have been fine except the extra
	-- walls would cost extra collisions, and collisions are more expensive
	-- in our simulation, so we prefer a more sparse map if we have to pick
	-- something other than 0.45.
	local scratch_index = 1
	local target = scratch_table[1]
	for y = 1, COLLISION_TABLE_HEIGHT do
		local r = target[y]
		for x = 1, COLLISION_TABLE_WIDTH do
			r[x] = (rand(101) < 45 and 1) or 0
		end

		-- Yield from init_world on every 4 rows of progress.  We yield once
		-- once every 4 rows as opposed to once on very row to reduce the
		-- number of calls to getElapsedTime().
		--
		-- We could increase the row batch size to reduce the cost even further,
		-- but we only have so much spare time at the end of each frame to do
		-- background initialization.
		if (y & 3) == 0 then
			init_progress += 1
			coroutine.yield()
		end
	end

	-- Apply a few rounds of smoothing to random values.
	for i = 1, 4 do
		local next_index <const> = 2 - scratch_index
		target = scratch_table[next_index]
		local source0 = scratch_table[scratch_index][1]
		local source1 = scratch_table[scratch_index][2]
		local source2 = scratch_table[scratch_index][3]
		for y = 2, COLLISION_TABLE_HEIGHT - 1 do
			local r = target[y]
			for x = 2, COLLISION_TABLE_WIDTH - 1 do
				r[x] =
				(
					source0[x - 1] + source0[x] + source0[x + 1] +
					source1[x - 1] + source1[x] + source1[x + 1] +
					source2[x - 1] + source2[x] + source2[x + 1]
				) // 5
			end

			source0 = source1
			source1 = source2
			source2 = scratch_table[scratch_index][y + 2]
			if (y & 3) == 0 then
				init_progress += 1
				coroutine.yield()
			end
		end
		scratch_index = next_index
	end

	-- Fill borders.
	target = scratch_table[scratch_index]
	for y = 1, GAME_AREA_MIN_Y - 1 do
		local r = target[y]
		for x = 1, COLLISION_TABLE_WIDTH do
			r[x] = 1  -- Top border.
		end
		if (y & 3) == 0 then
			init_progress += 1
			coroutine.yield()
		end
	end
	for y = GAME_AREA_MIN_Y, GAME_AREA_MAX_Y do
		local r = target[y]
		for x = 1, GAME_AREA_MIN_X - 1 do
			r[x] = 1  -- Left border.
		end
		for x = GAME_AREA_MAX_X + 1, COLLISION_TABLE_WIDTH do
			r[x] = 1  -- Right border.
		end
		if (y & 3) == 0 then
			init_progress += 1
			coroutine.yield()
		end
	end
	for y = GAME_AREA_MAX_Y + 1, COLLISION_TABLE_HEIGHT do
		local r = target[y]
		for x = 1, COLLISION_TABLE_WIDTH do
			r[x] = 1  -- Bottom border.
		end
		if (y & 3) == 0 then
			init_progress += 1
			coroutine.yield()
		end
	end

	-- Open up holes to ensure that objects have room to spawn.
	for i = 1, OBJECT_COUNT do
		local cell_x <const> = (world_positions[i][1] + 0x400) >> 11
		local cell_y <const> = (world_positions[i][2] + 0x400) >> 11
		target[cell_y][cell_x] = 0
		target[cell_y][cell_x + 1] = 0
		target[cell_y + 1][cell_x] = 0
		target[cell_y + 1][cell_x + 1] = 0
	end
	init_progress += 1
	coroutine.yield()

	-- Convert scratch_table entries from {0, 1} to {0, -1}.
	--
	-- This also fills the wall cells with 1 bits, which allows us
	-- to avoid a few shifts for the next step.
	for y = 1, COLLISION_TABLE_HEIGHT do
		local r = target[y]
		for x = 1, COLLISION_TABLE_WIDTH do
			r[x] = -r[x]
		end
		if (y & 3) == 0 then
			init_progress += 1
			coroutine.yield()
		end
	end

	-- Initialize wall tiles.
	local i = 1
	for x = 1, COLLISION_TABLE_WIDTH do
		wall_tiles[i] = 0x81  -- Top edge.
		i += 1
	end
	for y = 2, COLLISION_TABLE_HEIGHT - 1 do
		wall_tiles[i] = 0x81  -- Left edge.
		i += 1
		for x = 2, COLLISION_TABLE_WIDTH - 1 do
			-- Middle cells.
			--
			-- See generate_wall_tiles.c for indexing scheme.  Summary:
			--   +---+---+---+
			--   |   | 3 |   |
			--   +---+---+---+  Bits 0..3 encode adjacency.
			--   | 2 |   | 0 |  Bits 4..5 encode variations.
			--   +---+---+---+
			--   |   | 1 |   |
			--   +---+---+---+
			wall_tiles[i] =
				(target[y][x] ~= 0 and 0x81) or
				(
					(target[y][x + 1] & 0x01) +
					(target[y + 1][x] & 0x02) +
					(target[y][x - 1] & 0x04) +
					(target[y - 1][x] & 0x08) +
					(rand(0, 7) << 4) +
					1
				)
			i += 1
		end
		wall_tiles[i] = 0x81  -- Right edge.
		i += 1
		if (y & 3) == 0 then
			init_progress += 1
			coroutine.yield()
		end
	end
	for x = 1, COLLISION_TABLE_WIDTH do
		wall_tiles[i] = 0x81  -- Bottom edge.
		i += 1
	end

	-- Initialize floor tiles.  The first row is completely random.
	--
	-- Note that floor tiles near the borders would be completely hidden by
	-- the wall tiles above, which is why we can set the first row to
	-- completely random tiles and not worry about visual artifacts near
	-- clashing tile edges.
	i = 1
	for x = 1, FLOOR_TABLE_WIDTH do
		floor_tiles[i] = rand(256)
		i += 1
	end

	-- Tiles in subsequent rows need to match up with the row above.
	for y = 2, FLOOR_TABLE_HEIGHT do
		-- First tile in each row is completely random.
		local t = rand(0, 255)
		floor_tiles[i] = t + 1
		i += 1

		-- Remaining tiles need to match up with tile to the left and above.
		-- The is accomplished with our indexing scheme:
		--            +-----+
		--            |     |
		--            |    1|
		--            |  0  |
		--            +-----+
		--   +-----+  +-----+
		--   |     |  |  6  |  Bit 6 of new tile is bit 0 from tile above.
		--   |    1|  |7 ?  |  Bit 7 of new tile is bit 1 from tile to the left.
		--   |  0  |  |     |  Bits 0..5 are random.
		--   +-----+  +-----+
		for x = 2, FLOOR_TABLE_WIDTH do
			t = ((t & 2) << 6) |
			    (((floor_tiles[i - FLOOR_TABLE_WIDTH] - 1) & 1) << 6) |
			    rand(0, 63)
			floor_tiles[i] = t + 1
			i += 1
		end
		if (y & 3) == 0 then
			init_progress += 1
			coroutine.yield()
		end
	end

	-- Pick a single floor tile within the game area, and make it special.
	local special_x <const> = rand(WORLD_SIZE // 64 - 4) +
	                          (HORIZONTAL_PADDING // 64) + 2
	local special_y <const> = rand(WORLD_SIZE // 64 - 4) +
	                          (VERTICAL_PADDING // 64) + 2
	local special_index <const> = special_y * FLOOR_TABLE_WIDTH + special_x
	floor_tiles[special_index] = 256 + rand(16)

	-- Adjust edges of all neighbors of the special floor tile.
	set_floor_edge_bit(special_index - FLOOR_TABLE_WIDTH, 0x01)
	set_floor_edge_bit(special_index - 1, 0x02)
	set_floor_edge_bit(special_index + 1, 0x80)
	set_floor_edge_bit(special_index + FLOOR_TABLE_WIDTH, 0x40)

	-- The remaining steps must be done after game has completed.
	while game_in_progress do
		coroutine.yield()
	end

	-- Copy from scratch_table to collision_table.
	for y = 1, COLLISION_TABLE_HEIGHT do
		local r = target[y]
		for x = 1, COLLISION_TABLE_WIDTH do
			collision_table[y][x] = r[x]
		end
	end
	init_progress += 1
	coroutine.yield()

	-- Commit tile data.  This one single step is very expensive, and it
	-- takes longer than the time to render a single frame, so we can't
	-- hide it as a background task.
	--
	-- If we really want to hide this step, we could populate the cells
	-- one by one with setTileAtPosition, but that will take significantly
	-- more time overall.
	floor_tilemap:setTiles(floor_tiles, FLOOR_TABLE_WIDTH)
	floor_shift_x = rand(64)
	floor_shift_y = rand(64)
	respawn_x = (special_x << 3) - ((floor_shift_x + 4) >> 3) - 7
	respawn_y = (special_y << 3) - ((floor_shift_y + 4) >> 3) + 1
	assert(debug_respawn_tile_location())
	init_progress += 32
	coroutine.yield()

	wall_tilemap:setTiles(wall_tiles, COLLISION_TABLE_WIDTH)
	init_progress += 32
	coroutine.yield()
end

-- Randomize all objects and bring them to life.
local function init_world()
	-- Shuffle world positions with Fisher-Yates shuffle.
	--
	-- This will be used to assign initial positions to objects, which
	-- guarantees that the objects' initial positions are unique and
	-- evenly distributed.
	for i = #world_positions, 2, -1 do
		local j <const> = rand(1, i)
		world_positions[i][1], world_positions[j][1] = world_positions[j][1], world_positions[i][1]
		world_positions[i][2], world_positions[j][2] = world_positions[j][2], world_positions[i][2]
	end
	init_progress = 1
	coroutine.yield()

	-- Generate walls.  This needs to happen after world_positions are shuffled,
	-- since we need to make sure the spawning locations are empty.
	init_walls_and_floors()

	-- Assign object positions and set initial states.
	local p = 1
	for i = 1, OBJECT_COUNT do
		local obj = obj_table[i]
		obj.state = STATE_LIVE

		-- Set position.
		assert(is_empty(world_positions[p][1], world_positions[p][2]))
		obj.x = world_positions[p][1]
		obj.y = world_positions[p][2]
		p += 1
		assert(p <= #world_positions)

		-- Mark cells as occupied.
		set_occupant(obj.x, obj.y, i)

		-- Start with a random frame number.
		--
		-- Because objects only decide when to move at the end of their
		-- animation cycle, randomizing the initial frames will make
		-- the decision making frames distributed across all frames, as
		-- opposed to being clumped together at specific intervals.
		obj.frame = rand(1, 16)

		-- Start with a random initial angle.
		obj.a = rand(1, 32)
		obj.ta = obj.a

		-- Reset stun counter.
		obj.stun = 0
	end

	-- Reset population count.
	live_count[KIND_ROCK] = POPULATION_COUNT
	live_count[KIND_PAPER] = POPULATION_COUNT
	live_count[KIND_SCISSORS] = POPULATION_COUNT

	-- Reset clock.
	game_steps = 0
	action_frame_mask = 15

	-- Reset debug counters.
	assert(debug_count_reset())

	-- Final progress step.
	init_progress += 1
	assert(init_progress == MAX_INIT_PROGRESS)
end

-- Start measuring init_progress for current frame.
local function debug_init_world_progress_start()
	init_progress_watermark = init_progress
	return true
end

-- Show number of init_world steps completed in current frame.
--
-- This is drawn as a rectangle next to the FPS counter in debug builds.
-- We use this as an visual indication to know when init_world has started,
-- and also for measuring how much progress it's able to make from the
-- spare cycles.
local function debug_init_world_progress_show()
	local width <const> = init_progress - init_progress_watermark
	if width > 0 then
		gfx.setColor(gfx.kColorWhite)
		gfx.fillRect(40, 227, width + 2, 4)
		gfx.setColor(gfx.kColorBlack)
		gfx.fillRect(41, 228, width, 2)
	end
	return true
end

-- Synchronous version of init_world, used for benchmarks and simulation.
local function synchronous_init_world()
	assert(not game_in_progress)
	init_progress = 0
	local init_thread = coroutine.create(init_world)
	while coroutine.resume(init_thread) do end
	assert(init_progress == MAX_INIT_PROGRESS)
end

-- Run init_world in the background.
local function async_init_world()
	if not init_world_thread then
		init_progress = 0
		init_world_thread = coroutine.create(init_world)
	end
	assert(debug_init_world_progress_start())

	-- Call init_world_thread at least once, and keep going until we spent
	-- more than 0.025 seconds in the current frame.  We are targeting
	-- 30fps or 0.033 seconds per frame, so a threshold of 0.025 seconds should
	-- leave us with a bit of time to spare, assuming that init_world_thread
	-- yields in a few milliseconds.
	while coroutine.resume(init_world_thread) do
		if playdate.getElapsedTime() - frame_start_time > 0.025 then
			break
		end
	end
	assert(debug_init_world_progress_show())
end

-- Follow the next object that's alive.  Updates follow_index on return.
local function next_live_object(search_direction)
	-- For spectator mode, pick any next object that's alive.
	if player_kind == 0 then
		assert(live_kind_count() > 0)
		repeat
			follow_index += search_direction
			if follow_index > POPULATION_COUNT * 3 then
				follow_index = 1
			elseif follow_index <= 0 then
				follow_index = POPULATION_COUNT * 3
			end
		until obj_table[follow_index].state == STATE_LIVE
		return
	end

	-- For player-controlled modes, pick the next live object of the same kind,
	-- if that there are any remaining.
	if live_count[player_kind] == 0 then return end
	assert(obj_table[follow_index].kind == player_kind)
	repeat
		follow_index += 3 * search_direction
		if follow_index > POPULATION_COUNT * 3 then
			follow_index = player_kind
		elseif follow_index <= 0 then
			follow_index = player_kind + (POPULATION_COUNT - 1) * 3
		end
		assert(obj_table[follow_index].kind == player_kind)
	until obj_table[follow_index].state == STATE_LIVE
end

-- Given a nonzero vector, compute direction angle to reach that position.
local function get_direction(dx, dy)
	assert(dx ~= 0 or dy ~= 0)
	if abs(dx) >= abs(dy) then
		if dx > 0 then
			return coarse_atan[coarse_atan_steps][coarse_atan_steps * dy // dx]
		end
		return coarse_atan[-coarse_atan_steps][-coarse_atan_steps * dy // dx]
	end
	if dy > 0 then
		return coarse_atan[coarse_atan_steps * dx // dy][coarse_atan_steps]
	end
	return coarse_atan[-coarse_atan_steps * dx // dy][-coarse_atan_steps]
end
assert(get_direction(1, 0) == 1)
assert(get_direction(-1, 0) == 17)
assert(get_direction(0, 1) == 9)
assert(get_direction(0, -1) == 25)

assert(get_direction(2, 0) == 1)
assert(get_direction(-3, 0) == 17)
assert(get_direction(0, 5) == 9)
assert(get_direction(0, -7) == 25)

assert(get_direction(1, 1) == 5)
assert(get_direction(-1, 1) == 13)
assert(get_direction(1, -1) == 29)
assert(get_direction(-1, -1) == 21)

assert(get_direction(2, 1) > get_direction(1, 0))
assert(get_direction(1, 2) > get_direction(2, 1))
assert(get_direction(-1, 2) > get_direction(0, 1))
assert(get_direction(-2, 1) > get_direction(-1, 2))
assert(get_direction(-2, -1) > get_direction(-1, 0))
assert(get_direction(-1, -2) > get_direction(-2, -1))
assert(get_direction(1, -2) > get_direction(0, -1))
assert(get_direction(2, -1) > get_direction(1, -2))

-- Set direction to follow next live victim.
--
-- Auto-controlled objects only ever follow victims, and makes no attempt to
-- evade killers.  Turns out, just keep going in the same direction is a
-- reasonable strategy most of the time, because all objects move at the same
-- average speed, and killers will not catch up to victims until victims hit
-- obstacles.
--
-- Actually planning a path to hide behind obstacles would be expensive.
local function follow_next_victim(index, victim_kind)
	-- Nothing to do if there are no victims remaining.
	if live_count[victim_kind] <= 0 then
		return
	end

	-- Find the next live victim to follow.  Using this algorithm:
	--
	-- scan forward in the list objects:
	--
	--    if we see a victim, and skip_count is zero, that's the victim we want.
	--    otherwise:
	--       increment skip_count for each killer.
	--       decrement skip_count for each victim.
	--
	-- This is identical to how one might match parentheses in an expression,
	-- just imagine killers as "(" and victims as ")".
	--
	-- This scheme guarantees that all victims are matched up with at least
	-- one killer if the number of killers is greater than or equal to number
	-- of victims.  If there are more killers than victims, we will assign
	-- all the excess killers to which ever victim was last.
	--
	-- This loop is deterministic in selecting the same victim if the
	-- population of killers and victims remain constant.  If either
	-- population changed, it's possible for a killer to break off a chase
	-- due to index changes.  Players can observe when killers has selected
	-- a new victim and it might seem strange when that happens, but this
	-- is still the best scheme all around:
	--
	-- + It requires no maintenance of extra states.
	-- + It works even if all killers update at different time steps.
	-- + If there are more killers than victims, this scheme guarantees
	--   that every victim is followed by at least one killer.
	-- + Simulation shows that this scheme results in games with lowest
	--   average/median times.
	--
	-- Other schemes we have tried:
	-- - Assign the next victim whose numerical index is higher than the
	--   killer's numerical index.
	--
	--   This is even simpler than the current parentheses-matching scheme,
	--   but doesn't properly load balance the killers when there are
	--   consecutive victims.  It works for "()()" but not "(())".
	--
	-- - Add a "follower" count to victims' object states, tracking the
	--   number of killers that are actively following it.
	--
	--   This didn't work because killers aren't updated at every time step,
	--   thus the follower count is not accurate, which results in oscillating
	--   assignments.
	--
	-- - As an attempt to make the follower count accurate across update
	--   time steps, we changed "follower" a bitmask, where each killer
	--   hashes to a particular bit based on their own index, and would
	--   add their bit to the follower bitmask to mark a victim as being
	--   followed.  Other killers can count the number of bits in the
	--   follower bitmask and choose the victim with the fewest bit set.
	--
	--   This didn't work because the follower bits set by killers are not
	--   removed when the killer dies, thus most victims will have a fully
	--   populated follower set in a very short time.  We could avoid this
	--   if we were more generous in giving each killer a separate bit to
	--   avoid hash collisions, and thus we would be able to remove killer
	--   bits when they die, but this requires more state management.
	--
	-- - Instead of doing state tracking on the victim side, we could have
	--   a persistent index on the killer side to track which victim it's
	--   currently following, and only update that when the victim dies.
	--   This means killer will not break off a chase.
	--
	--   This didn't work because it doesn't load balance the victims among
	--   the killers.
	--
	--   Also, because all objects move at the same average speed, a
	--   killer+victim pair can be come phase locked such that the killer
	--   maintains the same distance behind a victim, and can not catch up
	--   to the victim off until the victim hits a wall.  With the mostly
	--   sparse maps that the simulation ran in, victims are able to outrun
	--   killers for extended amount of time, and killers occasionally
	--   changing directions to go after different victims turns out to make
	--   the games finish faster on average.
	local obj = obj_table[index]
	local scan_index = index
	local victim_index
	local victim_candidate
	local skip_count = 0
	for i = 1, POPULATION_COUNT * 3 do
		scan_index += 1
		if scan_index > POPULATION_COUNT * 3 then
			scan_index = 1
		end

		-- Only process live objects.
		if obj_table[scan_index].state == STATE_LIVE then
			if obj_table[scan_index].kind == victim_kind then
				-- Found a live victim.  If we meant to skip over this one,
				-- record the candidate index and move on.
				victim_candidate = scan_index
				if skip_count == 0 then
					-- Don't have any victims to skip over, this is the one we want.
					victim_index = scan_index
					break
				end
				skip_count -= 1
			elseif obj_table[scan_index].kind == obj.kind then
				-- Found a live killer of the same kind, increase the number
				-- of victims to skip over.
				skip_count += 1
			end
		end
	end

	-- If we ran out of victims to skip over, it means there are more killers
	-- remaining than victims.  We will send all the remainder to whatever
	-- was the last victim candidate we found.
	if not victim_index then
		victim_index = victim_candidate
	end
	assert(victim_index)
	local victim <const> = obj_table[victim_index]

	-- The victim can't be located on the same cell that killer is on,
	-- otherwise it would already be dead.
	local cell_x <const> = (obj.x + 0x400) >> 11
	local cell_y <const> = (obj.y + 0x400) >> 11
	assert(((victim.x + 0x400) >> 11) ~= cell_x or ((victim.y + 0x400) >> 11) ~= cell_y)

	-- Check where the victim will be in the next frame.
	local next_v <const> = velocity[victim.kind][victim.a][victim.frame]
	local next_x <const> = victim.x + next_v[1]
	local next_y <const> = victim.y + next_v[2]
	local next_cell_x <const> = (next_x + 0x400) >> 11
	local next_cell_y <const> = (next_y + 0x400) >> 11
	if cell_x == next_cell_x and cell_y == next_cell_y then
		-- Victim will soon arrive at where the killer is currently located.
		-- Killer should try to meet them head on.
		obj.ta = ((victim.a + 15) & 31) + 1
		return
	end

	-- Check where the victim will be 16 frames in the future, assuming that
	-- it kept going straight.  We need to look a bit ahead to intercept the
	-- path of the victim, but not too far ahead because the victim's
	-- location is less predictable in the future, and we end up doing a lot
	-- of overshooting.  Simulation tells us that lowest average/median game
	-- times happen when lookahead is set to 16, hence the current setting.
	local average_v <const> = average_velocity[victim.a]
	local future_x <const> = victim.x + 16 * average_v[1]
	local future_y <const> = victim.y + 16 * average_v[2]
	local future_cell_x <const> = (future_x + 0x400) >> 11
	local future_cell_y <const> = (future_y + 0x400) >> 11
	if cell_x == future_cell_x and cell_y == future_cell_y then
		-- Victim will arrive at where the killer is currently located.
		-- Killer should try to meet them head on.
		obj.ta = ((victim.a + 15) & 31) + 1
		return
	end

	-- Set target angle to arrive at where the victim will be.
	obj.ta = get_direction(future_x - obj.x, future_y - obj.y)
	if obj.ta == victim.a then
		-- If target angle is the same as the direction that the victim is
		-- currently going, it means killer and victim are on a parallel
		-- path that won't intersect.  Try setting target angle to point
		-- at where the victim is currently located instead.
		obj.ta = get_direction(next_x - obj.x, next_y - obj.y)
	end
end

-- Mark an object as having been killed by another.
local function kill_obj(index, killer)
	local obj = obj_table[index]

	-- Do nothing if object is already dead.  This can happen if the killer
	-- touched multiple collision cells at the same time.
	if obj.state ~= STATE_LIVE then return end

	set_occupant(obj.x, obj.y, 0)

	obj.state = STATE_DYING
	obj.frame = 1
	obj.ta = obj.a
	obj.ka = killer.a
	live_count[obj.kind] -= 1
end

-- Probabilistically remove a wall tile.
local function remove_wall_tile(tx, ty)
	-- Do not allow walls outside of the game area to be removed.
	if tx < GAME_AREA_MIN_X or tx > GAME_AREA_MAX_X or
	   ty < GAME_AREA_MIN_Y or ty > GAME_AREA_MAX_Y then
		return
	end

	-- Only allow walls to be removed with some probability.
	--
	-- We don't want walls to be removed on first hit because that makes
	-- them too easy to dig through, but we also don't want to do HP tracking
	-- for individual wall cells.  So we simulate HP by allowing walls to be
	-- probabilistically removed.
	--
	-- We have chosen a probability of about 1/3, but here we are generating
	-- a random number much larger than 3.  This is because generating random
	-- numbers is slightly expensive, so we will do it just once here, and
	-- use the lower bits to select tile variations, instead of generating
	-- 5 more random numbers.
	--
	-- Reducing the probability will make the walls more difficult to break,
	-- which in theory saves us a bit of CPU time.  But benchmark result shows
	-- very little difference when the probability is reduced to 1/4 and 1/5.
	-- Basically we would have to set the probability to be very low to get
	-- noticeable performance benefits, and at those thresholds the walls will
	-- start to feel very permanent.
	local r <const> = rand(0x30000)
	if r > 0x10000 then
		return
	end

	-- Mark space as empty.
	assert(collision_table[ty][tx] == -1)
	collision_table[ty][tx] = 0

	-- Update the affected cell, and also 4 adjacent neighbor cells.
	--
	-- Recall that this is our indexing scheme (from generate_wall_tiles.c):
	--   +---+---+---+
	--   |   | 3 |   |
	--   +---+---+---+  Bits 0..3 encode adjacency.
	--   | 2 |   | 0 |  Bits 4..5 encode variations.
	--   +---+---+---+
	--   |   | 1 |   |
	--   +---+---+---+
	--
	-- To update 5 cells, we need to read 5 rows from collision_table.
	local r0 <const> = collision_table[ty - 2]
	local r1 <const> = collision_table[ty - 1]
	local r2 <const> = collision_table[ty]
	local r3 <const> = collision_table[ty + 1]
	local r4 <const> = collision_table[ty + 2]

	-- All wall tiles are -1, which means they have their higher order bits
	-- set, unlike all live objects.  Thus we can get the bitmask for the
	-- tiles by shifting from the higher order bits.

	-- Update neighbor above.
	wall_tilemap:setTileAtPosition(
		tx, ty - 1,
		(r1[tx] < 0 and 0x81) or
		(
			(((r1[tx + 1] & 0x10000) |
			  (r2[tx    ] & 0x20000) |
			  (r1[tx - 1] & 0x40000) |
			  (r0[tx    ] & 0x80000)) >> 16) +
			((r << 4) & 0x70) +
			1
		))

	-- Update neighbor to the left.
	wall_tilemap:setTileAtPosition(
		tx - 1, ty,
		(r2[tx - 1] < 0 and 0x81) or
		(
			(((r2[tx    ] & 0x10000) |
			  (r3[tx - 1] & 0x20000) |
			  (r2[tx - 2] & 0x40000) |
			  (r1[tx - 1] & 0x80000)) >> 16) +
			((r << 1) & 0x70) +
			1
		))

	-- Update center cell.
	wall_tilemap:setTileAtPosition(
		tx, ty,
		(((r2[tx + 1] & 0x10000) |
		  (r3[tx    ] & 0x20000) |
		  (r2[tx - 1] & 0x40000) |
		  (r1[tx    ] & 0x80000)) >> 16) +
		((r >> 2) & 0x70) +
		1)

	-- Update neighbor to the right.
	wall_tilemap:setTileAtPosition(
		tx + 1, ty,
		(r2[tx + 1] < 0 and 0x81) or
		(
			(((r2[tx + 2] & 0x10000) |
			  (r3[tx + 1] & 0x20000) |
			  (r2[tx    ] & 0x40000) |
			  (r1[tx + 1] & 0x80000)) >> 16) +
			((r >> 5) & 0x70) +
			1
		))

	-- Update neighbor below.
	wall_tilemap:setTileAtPosition(
		tx, ty + 1,
		(r3[tx] < 0 and 0x81) or
		(
			(((r3[tx + 1] & 0x10000) |
			  (r4[tx    ] & 0x20000) |
			  (r3[tx - 1] & 0x40000) |
			  (r2[tx    ] & 0x80000)) >> 16) +
			((r >> 8) & 0x70) +
			1
		))

	-- Note that we re-derive the wall tiles from collision_table above,
	-- but what we could have done instead is to modify the existing tilemap
	-- without consulting collision_table, following these steps:
	--
	-- 1. Read existing tile index with getTileAtPosition.
	-- 2. Remove the corresponding neighbor bit.
	-- 3. Write the tile back with setTileAtPosition.
	--
	-- Doing it this way would preserve existing variation bits, but it's
	-- not like the tile variations were in any way precious.  It might be
	-- worthwhile if the extra function calls were cheaper than the extra
	-- bitwise operations we are doing here, but we have done this experiment
	-- and it turned out to not be cheaper, so we are not doing it.
end

-- Convert accelerometer readings from [-1,-1] range to rock velocities.
local function convert_accelerometer_unit(v)
	if v < 0 then
		return -convert_accelerometer_unit(-v)
	elseif v < ACCELEROMETER_DEADZONE then
		return 0
	elseif v >= ACCELEROMETER_MAX_TILT then
		return floor(ACCELEROMETER_MAX_VELOCITY)
	else
		return floor((v - ACCELEROMETER_DEADZONE) * ACCELEROMETER_MAX_VELOCITY / (ACCELEROMETER_MAX_TILT - ACCELEROMETER_DEADZONE))
	end
end

-- Interpret accelerometer readings as rock velocities.
--
-- Returns two integers in world coordinate units.
local function get_rock_velocity(ax, ay, az)
	assert(accelerometer_dx)
	assert(accelerometer_dy)
	assert(accelerometer_dz)
	local dx <const> = convert_accelerometer_unit(ax - accelerometer_dx)
	local dy <const> = convert_accelerometer_unit(ay - accelerometer_dy)

	-- Invert interpretation of dy if user configured zero is facing down.
	-- Interpretation of dx is always unchanged, because a left/right tilt
	-- still translates to left/right even if device is facing down.
	if accelerometer_dz < 0 then
		return dx, -dy
	else
		return dx, dy
	end
end

-- Interpret crank readings as scissors direction.
local function get_scissors_direction(a)
	return (floor(a * 32 / 360.0 + 24) & 31) + 1
end

-- Update all states for a single object.
local function update_obj(index)
	local obj = obj_table[index]

	-- Don't need to update dead objects.
	if obj.state == STATE_DEAD then return end

	-- Update dying animation.
	if obj.state == STATE_DYING then
		obj.frame += 1
		-- 24 came from DEATH_FRAMES in generate_animation_frames.pl
		if obj.frame == 24 then
			obj.state = STATE_DEAD

			-- If object is one that we are currently following, move on
			-- to the next object.
			if index == follow_index then
				next_live_object(1)
			end
		end
		return
	end

	-- Get current occupied cell location.
	local cell_x <const> = (obj.x + 0x400) >> 11
	local cell_y <const> = (obj.y + 0x400) >> 11

	-- Apply movement.
	local new_x, new_y
	if player_kind ~= 0 and follow_index == index then
		-- Under player control.
		if player_kind == KIND_ROCK then
			-- In rock mode, movement direction and speed are set by
			-- accelerometer.  Animation frame is only advanced if there
			-- is movement.
			--
			-- Player controlled rocks can go faster or slower than
			-- auto-controlled rocks, depending on how much tilt is applied.
			local ax <const>, ay <const>, az <const> = playdate.readAccelerometer()
			local dx <const>, dy <const> = get_rock_velocity(ax, ay, az)
			if dx == 0 and dy == 0 then
				-- Not enough tilt.  Don't move, and don't update animation either.
				new_x = obj.x
				new_y = obj.y
			else
				-- Set angle.
				obj.a = get_direction(dx, dy)

				-- Apply movement.
				new_x = obj.x + dx
				new_y = obj.y + dy

				-- Advance animation frame based on tilt angle.
				if abs(dx) >= average_velocity[1][1] or
				   abs(dy) >= average_velocity[1][2] then
					-- Double the frame rate when we saw enough tilt.
					obj.frame += 2
				else
					-- Regular frame rate.
					obj.frame += 1
				end
				if obj.frame > 16 then
					obj.frame -= 16
				end
			end

		elseif player_kind == KIND_PAPER then
			-- In paper mode, target direction is set by D-pad, and repeated
			-- presses on D-pad causes the animation to restart.  This means
			-- players can go at the usual speed by holding down on D-pad, or
			-- go faster by pressing D-pad repeatedly.  This means papers have
			-- the fastest velocity, if player is willing to mash on D-pad.
			--
			-- The intent is meant to simulate wind blowing with D-pad presses.

			-- Set target direction based on D-pad direction.
			local dx <const> =
				(playdate.buttonIsPressed(playdate.kButtonLeft) and -1 or 0) +
				(playdate.buttonIsPressed(playdate.kButtonRight) and 1 or 0)
			local dy <const> =
				(playdate.buttonIsPressed(playdate.kButtonUp) and -1 or 0) +
				(playdate.buttonIsPressed(playdate.kButtonDown) and 1 or 0)
			if dx ~= 0 or dy ~= 0 then
				obj.ta = get_direction(dx, dy)
			else
				obj.ta = obj.a
			end

			-- Reset animation on D-pad presses.
			if playdate.buttonJustPressed(playdate.kButtonUp) or
			   playdate.buttonJustPressed(playdate.kButtonDown) or
			   playdate.buttonJustPressed(playdate.kButtonLeft) or
			   playdate.buttonJustPressed(playdate.kButtonRight) then
				obj.frame = 1
			end

			if obj.frame == 16 then
				-- Wait for input in the final frame of the animation cycle.
				if dx ~= 0 or dy ~= 0 then
					-- Start a new animation cycle for the object.
					local v <const> = velocity[KIND_PAPER][obj.a][16]
					new_x = obj.x + v[1]
					new_y = obj.y + v[2]
					obj.frame = 1
				else
					-- Idling at final frame.
					new_x = obj.x
					new_y = obj.y
				end
			else
				-- Converge on the desired angle.
				obj.a = converge_angle[obj.a][obj.ta]
				assert(obj.a >= 1)
				assert(obj.a <= 32)

				local v <const> = velocity[KIND_PAPER][obj.a][obj.frame]
				new_x = obj.x + v[1]
				new_y = obj.y + v[2]
				obj.frame += 1
			end

		else
			-- In scissors mode, current direction (as opposed to target
			-- direction) is set by absolute crank position, and object continues
			-- moving through usual animation cycle.  This means scissors have
			-- the fastest turning speed.
			--
			-- Despite the fast turning speed, player controlled scissors do not
			-- have the same speed advantage available to rocks and papers.  This
			-- makes playing with scissors more difficult to win compared to
			-- rocks and papers.  This is the opposite to the observation we have
			-- with all auto-controlled objects, where scissors clearly has an
			-- edge over rocks and papers.  Number of wins after 5000 simulation
			-- runs:
			--
			--   rock wins = 1532 (31%)
			--   paper wins = 1046 (21%)
			--   scissors wins = 2422 (48%)
			--
			-- The fact that scissors movements are more erratic obviously has
			-- something to do with it, although I haven't done any rigorous
			-- research to explain this particular distribution of winnings.

			-- Crank range is [0, 360), with 0 pointing up, but we want [1, 32],
			-- with 1 pointing right.  Here we do the angle conversion to get
			-- the right range.
			--
			-- On simulator, we can see that the crank direction matches with
			-- the direction we want to go.  On the actual device, I had one
			-- instance where the direction was exactly opposite of where it
			-- should be, and the fix was to dock+undock the crank.  I couldn't
			-- reproduce that condition.
			obj.a = get_scissors_direction(playdate.getCrankPosition())
			assert(obj.a >= 1)
			assert(obj.a <= 32)

			local v <const> = velocity[KIND_SCISSORS][obj.a][obj.frame]
			new_x = obj.x + v[1]
			new_y = obj.y + v[2]
			obj.frame += 1
			if obj.frame == 17 then
				obj.frame = 1
			end
		end

	else
		-- Under automated control.  Converge on the desired target angle,
		-- then set the velocity accordingly.

		-- Converge on desired target angle.
		obj.a = converge_angle[obj.a][obj.ta]
		assert(obj.a >= 1)
		assert(obj.a <= 32)

		-- Animate object.
		obj.frame = (obj.frame & 15) + 1

		-- If object is currently stunned, don't move it until the stun effect
		-- has expired.  This gives the object a chance to turn, so that it
		-- doesn't run into the same obstacle again.
		--
		-- This only happens with auto-controlled objects.  Player controlled
		-- objects are never stunned.
		if obj.stun > 0 then
			obj.stun -= 1
			assert(debug_count_same_cell())
			return
		end

		-- Update velocity and compute new location.
		local v <const> = velocity[obj.kind][obj.a][obj.frame]
		new_x = obj.x + v[1]
		new_y = obj.y + v[2]

		-- Recompute target angle based on frame counter.  This happens only
		-- once every animation cycle at the beginning of the game, and
		-- gradually increases to once every frame as time progresses.
		if ((obj.frame - 1) & action_frame_mask) == 0 then
			-- Set new direction at the end of each animation cycle.  For all
			-- other frames, we will keep going at the same direction on
			-- inertia.  This saves a bit of processing time.
			--
			-- The first task in setting direction is to decide whether to
			-- pursue a victim or just keep going straight.  It might seem
			-- like we should be chasing victims all the time, but doing so
			-- may cause us to get stuck due to obstacles along the way.
			-- Also, when every object is in pursuit of some other object,
			-- the objects will tend to concentrate around the center of the
			-- map, which makes movements more crowded.  For better balance
			-- and variety, we will prefer to keep going straight when there
			-- are more victims remaining.  The heuristic is expressed in
			-- pseudocode as follows:
			--
			-- We encode this balance following this pseudocode:
			--
			--   if random > victim population + live population then
			--      follow victim
			--   else
			--      go straight
			--
			-- Intuitively:
			-- + A killer is more likely to follow a victim if the victim
			--   population is low.  This is because sparse victim density
			--   requires more deliberate effort to get killed off.
			--
			-- + A killer is more likely to follow a victim if the killer
			--   population is low.  If killer population is high, a
			--   killer can get lazy and let a different killer kill off
			--   whatever remains.
			--
			-- Note that because killer population count is always nonzero,
			-- there is always a small probability that a killer will break
			-- off a pursuit and go at a different direction.  If we didn't
			-- put in this bit, and there is exactly one object of each type
			-- remaining, we will get into a stalemate where all 3 objects
			-- will run around in circles.
			local victim_kind <const> = (obj.kind + 1) % 3 + 1
			if rand(POPULATION_COUNT) > live_count[victim_kind] + live_count[obj.kind] then
				follow_next_victim(index, victim_kind)
			end
		end
	end
	local new_cell_x <const> = (new_x + 0x400) >> 11
	local new_cell_y <const> = (new_y + 0x400) >> 11

	-- Check if we have moved on to a new collision cell.  If not, we don't
	-- need to do any of the unmarking/marking steps, and don't need to
	-- check for collisions.
	--
	-- This optimization works because the average velocity per frame is
	-- less than the size of a single collision cell, so around half the time
	-- the object would occupy the exact same set of collision cells after a
	-- single movement step.
	if cell_x == new_cell_x and cell_y == new_cell_y then
		obj.x = new_x
		obj.y = new_y
		assert(debug_count_same_cell())
		return
	end

	-- Unmark current collision cells.
	--
	-- We could have called set_occupant here, but inlining the function
	-- yields some measurable performance gains due to caching of
	-- collision_table references.  Since update_obj is the primary bottleneck
	-- of this game, we will take any performance gain we can get.
	assert(has_expected_occupant(obj.x, obj.y, index))
	local ct0 = collision_table[cell_y]
	local ct1 = collision_table[cell_y + 1]
	ct0[cell_x] = 0
	ct0[cell_x + 1] = 0
	ct1[cell_x] = 0
	ct1[cell_x + 1] = 0

	-- Check for existing object at destination.
	local nct0 = collision_table[new_cell_y]
	local nct1 = collision_table[new_cell_y + 1]
	local c00 <const> = nct0[new_cell_x]
	local c01 <const> = nct0[new_cell_x + 1]
	local c10 <const> = nct1[new_cell_x]
	local c11 <const> = nct1[new_cell_x + 1]
	local victim_kind <const> = (obj.kind + 1) % 3 + 1
	assert((obj.kind == KIND_ROCK and victim_kind == KIND_SCISSORS) or (obj.kind == KIND_PAPER and victim_kind == KIND_ROCK) or (obj.kind == KIND_SCISSORS and victim_kind == KIND_PAPER))

	-- If there are any object that can be defeated, they are removed
	-- right away.  For all other objects, stop the current movement and
	-- go back to where we started.  Stopping is the safest bet because we
	-- knew where we started was a valid spot.
	--
	-- Note that "other objects" include those that would kill the current
	-- object, so for example a rock running into paper will cause the rock
	-- to stop, but does not kill the rock.  There is no suicide in this game.
	local hit_obstacle = false
	if c00 ~= 0 then
		if c00 > 0 then
			if obj_table[c00].kind == victim_kind then
				kill_obj(c00, obj)
			else
				hit_obstacle = true
			end
		else
			remove_wall_tile(new_cell_x, new_cell_y)
			hit_obstacle = true
		end
	end
	if c01 ~= 0 then
		if c01 > 0 then
			if obj_table[c01].kind == victim_kind then
				kill_obj(c01, obj)
			else
				hit_obstacle = true
			end
		else
			remove_wall_tile(new_cell_x + 1, new_cell_y)
			hit_obstacle = true
		end
	end
	if c10 ~= 0 then
		if c10 > 0 then
			if obj_table[c10].kind == victim_kind then
				kill_obj(c10, obj)
			else
				hit_obstacle = true
			end
		else
			remove_wall_tile(new_cell_x, new_cell_y + 1)
			hit_obstacle = true
		end
	end
	if c11 ~= 0 then
		if c11 > 0 then
			if obj_table[c11].kind == victim_kind then
				kill_obj(c11, obj)
			else
				hit_obstacle = true
			end
		else
			remove_wall_tile(new_cell_x + 1, new_cell_y + 1)
			hit_obstacle = true
		end
	end

	if hit_obstacle then
		-- Hit an obstacle, roll back to the previous location and pick
		-- a new direction.
		obj.ta = ((obj.ta + rand(-8, 8)) & 31) + 1
		assert(obj.ta >= 1)
		assert(obj.ta <= 32)
		ct0[cell_x] = index
		ct0[cell_x + 1] = index
		ct1[cell_x] = index
		ct1[cell_x + 1] = index
		assert(debug_count_collision())

		-- Stun the object for a few frames so that it has a chance to turn.
		-- If we don't stun the object and keeps on moving, it will likely
		-- run into the same obstacle immediately, and collisions are more
		-- expensive to process.
		obj.stun = 4

	else
		-- Didn't hit any obstacles, so we can commit to the new position.
		obj.x = new_x
		obj.y = new_y
		nct0[new_cell_x] = index
		nct0[new_cell_x + 1] = index
		nct1[new_cell_x] = index
		nct1[new_cell_x + 1] = index
		assert(debug_count_no_collision())
	end
end

-- Update one of the slime objects.
--
-- This is essentially a simplified version of update_obj, optimized for the
-- fact that slimes never die, and never kill other objects.
local function update_slime(index)
	local obj = obj_table[index]

	-- Get current occupied cell location.
	local cell_x <const> = (obj.x + 0x400) >> 11
	local cell_y <const> = (obj.y + 0x400) >> 11

	-- Apply movement.  Slimes are always under automated control, and the
	-- only thing it needs to do is converge on the desired target angle
	-- and set velocity accordingly.
	assert(obj.a >= 1)
	assert(obj.a <= 32)
	assert(obj.ta >= 1)
	assert(obj.ta <= 32)
	obj.a = converge_angle[obj.a][obj.ta]
	assert(obj.a >= 1)
	assert(obj.a <= 32)

	-- Animate object.
	obj.frame = (obj.frame & 15) + 1

	-- Don't move if slime is currently stunned.
	if obj.stun > 0 then
		obj.stun -= 1
		return
	end

	-- Update velocity and compute new location.
	local v <const> = slime_velocity[obj.a]
	local new_x <const> = obj.x + v[1]
	local new_y <const> = obj.y + v[2]
	local new_cell_x <const> = (new_x + 0x400) >> 11
	local new_cell_y <const> = (new_y + 0x400) >> 11

	-- Check if we have moved on to a new collision cell.  If not, we don't
	-- need to do any of the unmarking/marking steps, and don't need to
	-- check for collisions.
	--
	-- This is the same optimization as in update_obj, and works even better
	-- here because slimes moves even slower.
	if cell_x == new_cell_x and cell_y == new_cell_y then
		obj.x = new_x
		obj.y = new_y
		return
	end

	-- Unmark current collision cells.
	assert(has_expected_occupant(obj.x, obj.y, index))
	local ct0 = collision_table[cell_y]
	local ct1 = collision_table[cell_y + 1]
	ct0[cell_x] = 0
	ct0[cell_x + 1] = 0
	ct1[cell_x] = 0
	ct1[cell_x + 1] = 0

	-- Check for existing object at destination.  We only need to check
	-- whether there are any objects there or not.  The response is the
	-- same independent of object kind (pick a new target direction and go).
	local nct0 = collision_table[new_cell_y]
	local nct1 = collision_table[new_cell_y + 1]
	if nct0[new_cell_x] ~= 0 or nct0[new_cell_x + 1] ~= 0 or
	   nct1[new_cell_x] ~= 0 or nct1[new_cell_x + 1] ~= 0 then
		-- Got a collision, roll back to the previous location and pick
		-- a new direction.
		obj.ta = ((obj.ta + rand(-8, 8)) & 31) + 1
		assert(obj.ta >= 1)
		assert(obj.ta <= 32)
		ct0[cell_x] = index
		ct0[cell_x + 1] = index
		ct1[cell_x] = index
		ct1[cell_x + 1] = index

		-- Set stun counter for this slime.  Note that stun time for slimes
		-- are longer than other objects, since they are not in a rush to
		-- go somewhere anyways.
		obj.stun = 8

	else
		-- No collision, so we can commit to the new position.
		obj.x = new_x
		obj.y = new_y
		nct0[new_cell_x] = index
		nct0[new_cell_x + 1] = index
		nct1[new_cell_x] = index
		nct1[new_cell_x + 1] = index
	end
end

-- Respawn a single extinct victim if the right object kind lands on
-- the respawn area.
local function maybe_respawn()
	-- Only respawn if there is exactly two kinds of object left.
	--
	-- If there are three kinds, the game is still balanced in the sense
	-- that any object can still be killed off.  If there is exactly one
	-- kind remaining, the game has already completed with a winner.
	if live_kind_count() ~= 2 then
		return
	end

	local respawn_kind
	local trigger_kind
	if live_count[KIND_ROCK] == 0 then
		-- Paper can revive rocks.
		trigger_kind = KIND_PAPER
		respawn_kind = KIND_ROCK
	elseif live_count[KIND_PAPER] == 0 then
		-- Scissors can revive papers.
		trigger_kind = KIND_SCISSORS
		respawn_kind = KIND_PAPER
	else
		-- Rocks can revive scissors.
		trigger_kind = KIND_ROCK
		respawn_kind = KIND_SCISSORS
	end

	-- If the object that would have been respawned is player-controlled,
	-- we will not allow the respawn to happen, because we are already in
	-- game_over state.
	if respawn_kind == player_kind then
		return
	end

	for y = 0, 5 do
		local ry <const> = respawn_y + y

		-- Skip over the middle 16 cells, and only check the 20 cells along
		-- the border of the 6x6 respawn area.
		--
		-- We do this because objects don't move all that fast, so they are
		-- guaranteed to land on a border cell before reaching the middle
		-- cells.  Benchmark suggests that we would save a few microseconds
		-- by skipping those 16 cells.
		local step <const> = (y == 0 or y == 5) and 1 or 5

		for x = 0, 5, step do
			local rx <const> = respawn_x + x
			local i <const> = collision_table[ry][rx]
			if i > 0 and obj_table[i].kind == trigger_kind then
				-- Find an object that died outside of the visible area, and
				-- currently doesn't have some other object on top of it.
				--
				-- It is possible but extremely unlikely that we would go through
				-- all dead objects, and none of them are eligible to be respawned.
				-- In that case the respawn just wouldn't happen, but nothing else
				-- will break.  The more common case is that we would find a usable
				-- candidate after checking just a few objects.
				--
				-- Across 1987 respawns during simulation runs:
				--
				--   1822 (92%) respawned after checking just one object.
				--   1982 (99%) respawned after checking one or two objects.
				--   1987 (100%) respawned after checking three or fewer objects.
				for v = respawn_kind, respawn_kind + 3 * (POPULATION_COUNT - 1), 3 do
					local obj = obj_table[v]
					assert(obj.kind == respawn_kind)
					assert(obj.state ~= STATE_LIVE)

					local cell_x <const> = (obj.x + 0x400) >> 11
					local cell_y <const> = (obj.y + 0x400) >> 11
					local view_cell_x <const> = view_x >> 3
					local view_cell_y <const> = view_y >> 3
					if (cell_x < view_cell_x - 26 or cell_x > view_cell_x + 26 or
					    cell_y < view_cell_y - 16 or cell_y > view_cell_y + 16) and
					   collision_table[cell_y][cell_x] == 0 and
					   collision_table[cell_y][cell_x + 1] == 0 and
					   collision_table[cell_y + 1][cell_x] == 0 and
					   collision_table[cell_y + 1][cell_x + 1] == 0 then
						assert(debug_log(string.format("respawned %d at (%d,%d) [%d,%d]", v, obj.x, obj.y, cell_x, cell_y)))
						obj.state = STATE_LIVE
						obj.frame = rand(1, 16)
						collision_table[cell_y][cell_x] = v
						collision_table[cell_y][cell_x + 1] = v
						collision_table[cell_y + 1][cell_x] = v
						collision_table[cell_y + 1][cell_x + 1] = v
						assert(has_expected_occupant(obj.x, obj.y, v))
						assert(live_count[obj.kind] == 0)
						live_count[obj.kind] = 1
						assert(debug_mark_respawned_spot(cell_x, cell_y))
						return
					end
				end
			end
		end
	end
end

-- Update all objects.
local function run_simulation_step()
	-- Update all object states.
	for i = 1, POPULATION_COUNT * 3 do
		update_obj(i)
	end
	for i = POPULATION_COUNT * 3 + 1, OBJECT_COUNT do
		update_slime(i)
	end
	maybe_respawn()

	-- Increase action sampling frequency as game progresses.
	--
	-- Sampling is based on time (game_steps) rather than population count,
	-- since it's sometimes the case that where game has ran longer than usual,
	-- but we still have quite a few objects left.  We still want to increase
	-- accuracy in those cases so that the games would finish, despite the
	-- increased CPU cost.
	game_steps += 1
	if game_steps == 450 then
		assert(action_frame_mask == 15)
		action_frame_mask = 7
		assert(debug_count_report())
	elseif game_steps == 900 then
		assert(action_frame_mask == 7)
		action_frame_mask = 3
		assert(debug_count_report())
	elseif game_steps == 1350 then
		assert(action_frame_mask == 3)
		action_frame_mask = 1
		assert(debug_count_report())
	end
end

-- Benchmark for various update functions.
local function run_benchmarks()
	if not playdate.isSimulator then return true end

	debug_log("Running benchmarks")

	local STEP_COUNT <const> = 90
	local init_world_time = 0
	local update_obj_time = 0
	local cycles = 0
	local cumulative_same_cell_count = 0
	local cumulative_no_collision_count = 0
	local cumulative_collision_count = 0
	repeat
		local t0 <const> = playdate.getElapsedTime()
		synchronous_init_world()

		local t1 <const> = playdate.getElapsedTime()
		for i = 1, STEP_COUNT do
			run_simulation_step()
		end
		local t2 <const> = playdate.getElapsedTime()

		init_world_time += t1 - t0
		update_obj_time += t2 - t1
		cycles += 1
		cumulative_same_cell_count += global_debug_count_same_cell
		cumulative_no_collision_count += global_debug_count_no_collision
		cumulative_collision_count += global_debug_count_collision
	until init_world_time + update_obj_time >= 3
	local steps <const> = cycles * STEP_COUNT
	print(string.format("init_world: cycles=%d, time per cycle=%f", cycles, init_world_time / cycles))
	print(string.format("update_obj/update_slime: cycles=%d, steps=%d, time per cycle=%f, time per step=%f", cycles, steps, update_obj_time / cycles, update_obj_time / steps))
	print("same_cell=" .. global_debug_count_same_cell ..
	      ", no_collision=" .. global_debug_count_no_collision ..
	      ", collision=" .. global_debug_count_collision)
	return true
end
assert(run_benchmarks())

-- Make a simulate_game() function visible to the simulator, which runs
-- updates repeatedly until game completes, without drawing anything.
--
-- This is used to check heuristic tweaks to see how they affect
-- auto-controlled objects (generally we would only accept changes
-- that reduce the average or median number of game steps).  It also serves
-- as a sort of stress test to- make sure we don't trip over any assertions.
--
-- To use, wait for game to finish loading and running benchmarks, pause
-- the game, and then run this in the console:
--
--   simulate_game(seed)
--
-- Where "seed" is the seed number.  Same seed number should always result
-- in same simulation outcome, otherwise it's a bug.
--
-- Simulator should be paused before calling simulate_game(), since
-- simulate_game() operates on the same data that would have been used
-- in the real game.  Similarly, game should be reloaded after calling
-- simulate_game(), because playing with a game state leftover from
-- simulate_game() runs will lead to undefined behavior.
local function export_simulate_game_function_for_debug()
	simulate_game = function(seed)
		debug_log("simulate_game(" .. seed .. ")")
		math.randomseed(seed)
		init_world_positions()
		synchronous_init_world()
		local steps = 0
		repeat
			run_simulation_step()
			steps += 1
		until live_kind_count() == 1

		if live_count[KIND_ROCK] > 0 then
			debug_log("rock wins, steps = " .. steps)
		elseif live_count[KIND_PAPER] > 0 then
			debug_log("paper wins, steps = " .. steps)
		else
			debug_log("scissors wins, steps = " .. steps)
		end
	end
	return true
end
assert(export_simulate_game_function_for_debug())

-- Update view to follow the selected object.
local function update_view()
	local obj <const> = obj_table[follow_index]

	-- Try a more complex camera update scheme for these objects:
	-- + Live scissors that are player controlled or auto-controlled.
	-- + Live papers that are auto-controlled.
	--
	-- The complex scheme is meant to maintain constant velocity in camera
	-- movement, to avoid the constant acceleration and deceleration we get
	-- with papers and scissors.  We don't need it for rocks because rocks
	-- already move at constant velocity.
	--
	-- This scheme is not used for player controlled papers because those
	-- objects can accelerate in different directions very quickly, and the
	-- prediction scheme will often get it wrong.  The pulsating camera
	-- movement is unfortunate, but it's still better than the sudden jerks
	-- we get from rapid player input.
	if obj.state == STATE_LIVE and obj.kind ~= KIND_ROCK and
	   (obj.kind == KIND_SCISSORS or player_kind ~= KIND_PAPER) then
		local dx <const> = obj.x + average_velocity[obj.a][1] - view_world_x
		local dy <const> = obj.y + average_velocity[obj.a][2] - view_world_y
		if abs(dx) <= 768 and abs(dy) <= 768 then
			-- Don't update viewport if object is within few pixels of being
			-- centered.  This avoids a situation where the object is going
			-- up against a wall, and we projected the camera to move one step
			-- ahead, and then having to move the camera back in the next frame.
			--
			-- This also means that the camera is actually always slightly
			-- behind object the object we want to follow.
			return
		end
		local view_direction <const> = get_direction(dx, dy)
		local next_x <const> = view_world_x + average_velocity[view_direction][1]
		local next_y <const> = view_world_y + average_velocity[view_direction][2]

		-- Set projected position to be the new camera position if it's
		-- close enough.
		if abs(next_x - obj.x) < 8192 and abs(next_y - obj.y) < 8192 then
			view_world_x = next_x
			view_world_y = next_y
			view_x = view_world_x >> 8
			view_y = view_world_y >> 8
			return
		end
	end

	-- Make camera position converge on object location.  This causes the
	-- camera to be locked on to the object within a few frames, keeping
	-- it in the center of the view.
	view_world_x = (view_world_x + obj.x) >> 1
	view_world_y = (view_world_y + obj.y) >> 1
	view_x = view_world_x >> 8
	view_y = view_world_y >> 8
end

-- Draw background tiles.
local function draw_background()
	-- Here we can drop the lowest bit such that screen scrolling always
	-- happen in units of 2, according to the recommendations here:
	-- https://help.play.date/developer/designing-for-playdate/#dither-flashing
	--
	-- We are not doing that because for the dither pattern used in our
	-- floor tiles, it didn't seem to make much difference either way.
	-- On the simulator the shimmering effect is not noticeable where we
	-- drop the lowest bit or not, and on the device the shimmering effect is
	-- always there if we want to look for it.
	local aligned_x <const> = 200 - view_x
	local aligned_y <const> = 120 - view_y
	floor_tilemap:draw(aligned_x - floor_shift_x, aligned_y - floor_shift_y)
	wall_tilemap:draw(aligned_x, aligned_y)
end

-- Draw all objects.
local function draw_objects()
	-- Draw all the dead+dying sprites first.
	for i = 1, OBJECT_COUNT do
		local obj <const> = obj_table[i]
		if obj.state ~= STATE_LIVE then
			assert(obj.state == STATE_DEAD or obj.state == STATE_DYING)
			local screen_x <const> = obj.x >> 8
			local screen_y <const> = obj.y >> 8
			-- 232 = 400 / 2 + 32
			-- 152 = 240 / 2 + 32
			if screen_x >= view_x - 232 and screen_x <= view_x + 232 and
			   screen_y >= view_y - 152 and screen_y <= view_y + 152 then
				assert(obj.a >= 1)
				assert(obj.a <= 32)
				assert(obj.frame >= 1)
				if obj.kind == KIND_ROCK then
					-- Rock death sprites are 32x32.
					sprites32:drawImage(
						animation_frame[obj.kind][STATE_DYING][obj.a][obj.frame],
						screen_x - view_x + 184,  -- 184 = 400 / 2 - 16
						screen_y - view_y + 104)  -- 104 = 240 / 2 - 16
				elseif obj.kind == KIND_SCISSORS then
					-- Scissors death sprites are 64x64.
					sprites64:drawImage(
						animation_frame[obj.kind][STATE_DYING][obj.a][obj.frame],
						screen_x - view_x + 168,  -- 168 = 400 / 2 - 32
						screen_y - view_y + 88)   -- 88 = 240 / 2 - 32
				else
					assert(obj.kind == KIND_PAPER)
					-- Paper death sprites are also 64x64, but came from
					-- a special table.
					assert(obj.ka >= 1)
					assert(obj.ka <= 32)
					sprites64:drawImage(
						paper_frames[obj.a][obj.ka][obj.frame],
						screen_x - view_x + 168,  -- 168 = 400 / 2 - 32
						screen_y - view_y + 88)   -- 88 = 240 / 2 - 32
				end
			end
		end
	end

	-- Draw live sprites on top of dead sprites, and also keep track of where
	-- the out of bounds sprites are located.
	local arrow_right, arrow_down_right, arrow_down, arrow_down_left
	local arrow_left, arrow_up_left, arrow_up, arrow_up_right
	local victim_kind
	if player_kind ~= 0 then
		victim_kind = (player_kind + 1) % 3 + 1
	end
	for i = 1, OBJECT_COUNT do
		local obj <const> = obj_table[i]
		if obj.state == STATE_LIVE then
			local screen_x <const> = obj.x >> 8
			local screen_y <const> = obj.y >> 8

			-- Compute vector from center of viewing window to sprite.
			local dx <const> = screen_x - view_x
			local dy <const> = screen_y - view_y

			if obj.kind == victim_kind then
				-- Object is something that can be killed by player object.
				-- If it's out of bounds, we will need to keep track of which
				-- direction it's out of bounds for drawing arrows later.
				--
				-- Note that we draw at most arrow for each of the 8 directions.
				-- Alternatively, we could draw one arrow per object with a more
				-- accurate direction, but that costs a significant drop in frame
				-- rate, and also makes the screen look very crowded.
				if dx < -216 then
					if dy < dx // 2 then
						arrow_up_left = true
					elseif dy > -dx // 2 then
						arrow_down_left = true
					else
						arrow_left = true
					end
				elseif dx > 216 then
					if dy < -dx // 2 then
						arrow_up_right = true
					elseif dy > dx // 2 then
						arrow_down_right = true
					else
						arrow_right = true
					end
				elseif dy < -136 then
					if dx < dy // 2 then
						arrow_up_left = true
					elseif dx > -dy // 2 then
						arrow_up_right = true
					else
						arrow_up = true
					end
				elseif dy > 136 then
					if dx < -dy // 2 then
						arrow_down_left = true
					elseif dx > dy // 2 then
						arrow_down_right = true
					else
						arrow_down = true
					end
				else
					-- Object is partially or fully visible.
					assert(obj.a >= 1)
					assert(obj.a <= 32)
					assert(obj.frame >= 1)
					assert(obj.frame <= 16)
					sprites32:drawImage(
						animation_frame[obj.kind][STATE_LIVE][obj.a][obj.frame],
						dx + 184,  -- 184 = 400 / 2 - 16
						dy + 104)  -- 104 = 240 / 2 - 16
				end
			else
				-- Object is not something that can be killed by the player.
				-- We only need to check bounds to decide whether to draw the
				-- sprite or not.
				if dx >= -216 and dx <= 216 and dy >= -136 and dy <= 136 then
					assert(obj.a >= 1)
					assert(obj.a <= 32)
					assert(obj.frame >= 1)
					assert(obj.frame <= 16)
					sprites32:drawImage(
						animation_frame[obj.kind][STATE_LIVE][obj.a][obj.frame],
						dx + 184,  -- 184 = 400 / 2 - 16
						dy + 104)  -- 104 = 240 / 2 - 16
				end
			end
		end
	end

	-- Draw arrows to point at victims that are outside of current view.
	if arrow_up_left then
		misc2_images:drawImage(6, 4, 4)
	end
	if arrow_up then
		misc2_images:drawImage(7, 184, 4)
	end
	if arrow_up_right then
		misc2_images:drawImage(8, 380, 4)
	end
	if arrow_left then
		misc2_images:drawImage(5, 4, 104)
	end
	if arrow_right then
		misc2_images:drawImage(1, 380, 104)
	end
	if arrow_down_left then
		misc2_images:drawImage(4, 4, 220)
	end
	if arrow_down then
		misc2_images:drawImage(3, 184, 220)
	end
	if arrow_down_right then
		misc2_images:drawImage(2, 380, 224)
	end
end

-- Draw population counts.
local function draw_population(count, x, y)
	-- 1234567890123456
	-- (rr## pp## ss##)
	local tiles =
	{
		19,            -- (
		1, 2, 17, 17,  -- Rock count = [4], [5]
		17,            -- Space
		3, 4, 17, 17,  -- Paper count = [9], [10]
		17,            -- Space
		5, 6, 17, 17,  -- Scissors count = [14], [15]
		20             -- )
	}
	for i = 1, 3 do
		-- See POPULATION_COUNT constant for why we only need two digits.
		--
		-- If we want to have a population count greater than 2 digits, it
		-- would be better to show "99" here than to show the full 3 digits,
		-- because the initial population tend to get killed off quickly and
		-- the game soon drops to 2 digit population counts anyways.
		assert(count[i] <= 99)
		if count[i] > 9 then
			tiles[i * 5 - 1] = count[i] // 10 + 7
			tiles[i * 5] = count[i] % 10 + 7
		else
			tiles[i * 5 - 1] = count[i] % 10 + 7
		end
	end
	status_box:setTiles(tiles, 16)
	status_box:draw(x, y)
end

-- Run a simulation step and draw all objects.
local function run_game_step()
	run_simulation_step()
	update_view()

	-- Note that we don't do a "gfx.clear()" here, since floor_tilemap
	-- will completely cover the screen, so we can just draw over the
	-- previous frame without clearing it.
	draw_background()
	draw_objects()

	-- Draw status box near bottom right.  It's positioned there to
	-- avoid overlapping with the arrows near the corners.
	--
	-- An earlier version have a bit of extra logic to make the box
	-- change position based on which direction the player is facing,
	-- but the jumpy box didn't seem to add much value, so now we just
	-- have it stay in the same place.
	draw_population(live_count, 236, 225)
end

--}}}

----------------------------------------------------------------------
--{{{ Game states and callbacks.

local game_loop

-- Wait for initialization to complete.
local function game_init()
	-- Generate fade out animation by drawing translucent rectangle over the
	-- whole screen.
	--
	-- If we already made sufficient progress before entering game_init state,
	-- start by drawing 25% and 50% rectangles for the first two frames.  This
	-- makes the transition less abrupt.
	for i = 1, 2 do
		-- If reset is requested, skip the reset of game_init and just return.
		-- game_state should be set to game_select already, but we can't check
		-- it here because game_select is declared further down in this file.
		--
		-- If we don't return early here (and also the next two places),
		-- game_init will proceed with the rest of the initialization steps,
		-- and eventually set game_state to game_loop, ignoring the reset
		-- command.
		--
		-- We only need this extra reset_requested check for game_init because
		-- it uses coroutines, and maintains states inside local variables.
		-- The other functions always return control to playdate.update after
		-- rendering one frame, and reset will work correctly without needing
		-- this extra check.
		if reset_requested then
			return
		end
		if init_progress * i > MAX_INIT_PROGRESS // 4 then
			-- Note that we set current drawing color to white, and then set
			-- dither pattern so that we draw white rectangles with
			-- transparencies.  This is the only sequence that would work.
			-- If we set dither pattern without setting current color, we will
			-- end up drawing black rectangles with transparencies.
			gfx.setColor(gfx.kColorWhite)
			gfx.setDitherPattern(1.0 - (i / 4.0))
			gfx.fillRect(0, 0, 400, 240)

			-- No "loading" text for these 2 frames.  This is so that if all
			-- initialization were completed in the background, player wouldn't
			-- see any loading text at all.
			async_init_world()
			coroutine.yield()
		end
	end
	while init_progress < MAX_INIT_PROGRESS do
		if reset_requested then
			return
		end

		-- Fade out, with rectangle opacity matching initialization progress.
		gfx.setColor(gfx.kColorWhite)
		gfx.setDitherPattern(1.0 - init_progress / MAX_INIT_PROGRESS)
		gfx.fillRect(0, 0, 400, 240)

		-- 7 = "Loading..." - 98 pixels.
		text_images:drawImage(7, 300, 220)

		async_init_world()
		coroutine.yield()
	end

	-- Done with initialization.
	assert(not coroutine.resume(init_world_thread))
	init_world_thread = nil

	-- Choose an object to follow.  This can't be done inside
	-- init_world_thread because player_kind is not decided until
	-- we leave game_select state.
	if player_kind == 0 then
		-- Follow a random object in spectator mode.
		follow_index = rand(3)
	else
		-- Follow first object in player's selected mode.
		follow_index = player_kind
		assert(obj_table[follow_index].kind == player_kind)
	end

	-- Kill off excess objects in accordance with population_test setting.
	for i = 1, 3 do
		assert(population_limit[i] >= 1)
		assert(population_limit[i] <= POPULATION_COUNT)
		local excess <const> = live_count[i] - population_limit[i]
		if excess > 0 then
			for j = 1, excess do
				local obj = obj_table[i + j * 3]
				obj.state = STATE_DEAD
				obj.frame = 24
				obj.ta = obj.a
				obj.ka = rand(1, 32)
				set_occupant(obj.x, obj.y, 0)
			end
			live_count[i] = population_limit[i]
		end
	end

	-- Center view on selected object.
	view_world_x = obj_table[follow_index].x
	view_world_y = obj_table[follow_index].y
	view_x = view_world_x >> 8
	view_y = view_world_y >> 8

	-- Draw a completely white frame.  We need this frame because the waiting
	-- loop above ends after init_progress has reached maximum, but we didn't
	-- draw the last frame with full opacity, which is why we are drawing it
	-- here.
	--
	-- Without this white frame, we would see an almost blank screen transition
	-- into the fade-in sequence immediately, and it just feels slightly off.
	gfx.clear()
	coroutine.yield()

	-- Fade in the game field screen for a few frames.
	--
	-- This is done by repeatedly drawing the game objects and tilemaps without
	-- updating any object positions (i.e. draw without simulate), and then
	-- draw translucent strips of rectangles above the game objects.  Fade-in
	-- effect is achieved by drawing progressively more transparent strips.
	--
	-- Alternatively, we could render the game objects and save that as an
	-- image so that we don't have to render the same frame from scratch
	-- repeatedly.  But since we are able to render it fast enough, we didn't
	-- bother trying the image caching approach.
	gfx.setColor(gfx.kColorWhite)
	for i = 1, 15 do
		if reset_requested then
			return
		end

		-- Draw game objects and tiles.
		draw_background()
		draw_objects()

		-- Draw center stripe.
		if i < 8 then
			gfx.setColor(gfx.kColorWhite)
			gfx.setDitherPattern(i / 8.0)
			gfx.fillRect(0, 112, 400, 16)
		end

		-- Draw stripes above and below.
		for j = 1, 7 do
			if i - j < 8 then
				gfx.setColor(gfx.kColorWhite)
				if i > j then
					gfx.setDitherPattern((i - j) / 8.0)
				end
				gfx.fillRect(0, 112 - j * 16, 400, 16)
				gfx.fillRect(0, 112 + j * 16, 400, 16)
			end
		end

		coroutine.yield()
	end

	-- Start or stop accelerometer depending on selected game mode.
	if player_kind == KIND_ROCK then
		playdate.startAccelerometer()
	else
		playdate.stopAccelerometer()
	end

	-- Start game loop.
	assert(debug_log("Game started"))
	game_state = game_loop
	game_in_progress = true
end

-- Hidden backdoor for testing accelerometer operations.  Hold "up" at
-- mode selection screen for 3 seconds to enable, press "down" to dismiss.
local function accelerometer_test()
	-- Check for backdoor activation.
	if accelerometer_test_timer < INPUT_TEST_TIMER then
		if playdate.buttonIsPressed(playdate.kButtonUp) then
			accelerometer_test_timer += 1
			if accelerometer_test_timer < INPUT_TEST_TIMER then
				return
			end

			-- Backdoor enabled.  Turn accelerometer on if it's not on already.
			if not playdate.accelerometerIsRunning() then
				playdate.startAccelerometer()
			end
		else
			accelerometer_test_timer = 0
			return
		end
	end

	-- Make sure the other backdoors are hidden.
	crank_test_timer = 0
	population_test_timer = 0

	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(85, 44, 230, 150)
	gfx.setColor(gfx.kColorBlack)
	gfx.drawRect(85, 44, 230, 150)

	gfx.drawText("*Accelerometer test*", 127, 48)
	local ax <const>, ay <const>, az <const> = playdate.readAccelerometer()
	gfx.drawText(string.format("x = %+.3f", ax), 92, 75)
	gfx.drawText(string.format("y = %+.3f", ay), 92, 97)
	gfx.drawText(string.format("z = %+.3f", az), 92, 119)
	gfx.drawText(string.format("(zero = %+.3f)", accelerometer_dx), 185, 75)
	gfx.drawText(string.format("(zero = %+.3f)", accelerometer_dy), 185, 97)
	gfx.drawText(string.format("(zero = %+.3f)", accelerometer_dz), 185, 119)

	local dx <const>, dy <const> = get_rock_velocity(ax, ay, az)
	gfx.drawText(string.format("dx = %+d", dx), 92, 146)
	gfx.drawText(string.format("dy = %+d", dy), 92, 168)

	if dx ~= 0 or dy ~= 0 then
		example_direction = get_direction(dx, dy)
	end
	assert(example_direction >= 1)
	assert(example_direction <= 32)
end

-- Hidden backdoor for testing crank operations.  Hold "right" at mode
-- selection screen for 3 seconds to enable, press "down" to dismiss.
local function crank_test()
	-- Check for backdoor activation.
	if crank_test_timer < INPUT_TEST_TIMER then
		if playdate.buttonIsPressed(playdate.kButtonRight) then
			crank_test_timer += 1
			if crank_test_timer < INPUT_TEST_TIMER then
				return
			end
		else
			crank_test_timer = 0
			return
		end
	end

	-- Backdoor enabled.  Make sure the other backdoors are hidden.
	accelerometer_test_timer = 0
	population_test_timer = 0

	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(135, 78, 130, 84)
	gfx.setColor(gfx.kColorBlack)
	gfx.drawRect(135, 78, 130, 84)

	gfx.drawText("*Crank test*", 160, 82)
	local a <const> = playdate.getCrankPosition()
	gfx.drawText(string.format("a = %.3f", a), 142, 109)

	example_direction = get_scissors_direction(a)
	assert(example_direction >= 1)
	assert(example_direction <= 32)
	gfx.drawText(string.format("d = %d", example_direction), 142, 136)
end

-- Hidden backdoor for adjusting initial populations.  Hold "left" at mode
-- selection screen for 3 seconds to enable, press "down" to dismiss.
local function population_test()
	-- Check for backdoor activation.
	if population_test_timer < INPUT_TEST_TIMER then
		if playdate.buttonIsPressed(playdate.kButtonLeft) then
			population_test_timer += 1
			if population_test_timer < INPUT_TEST_TIMER then
				return
			end
		else
			population_test_timer = 0
			return
		end
	end

	-- Backdoor enabled.  Make sure the other backdoors are hidden.
	accelerometer_test_timer = 0
	crank_test_timer = 0

	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(85, 48, 229, 143)
	gfx.setColor(gfx.kColorBlack)
	gfx.drawRect(85, 48, 229, 143)

	gfx.drawText("*Set initial population*", 127, 54)
	draw_population(population_limit, 139, 80)


	local delta <const> = floor(playdate.getCrankChange() / 2)
	if playdate.buttonIsPressed(playdate.kButtonUp) then
		gfx.drawText("*Up+Crank: adjust rocks*", 92, 103)
		population_limit[KIND_ROCK] += delta
	else
		gfx.drawText("Up+Crank: adjust rocks", 92, 103)
	end
	if playdate.buttonIsPressed(playdate.kButtonLeft) then
		gfx.drawText("*Left+Crank: adjust papers*", 92, 125)
		population_limit[KIND_PAPER] += delta
	else
		gfx.drawText("Left+Crank: adjust papers", 92, 125)
	end
	if playdate.buttonIsPressed(playdate.kButtonRight) then
		gfx.drawText("*Right+Crank: adjust scissors*", 92, 147)
		population_limit[KIND_SCISSORS] += delta
	else
		gfx.drawText("Right+Crank: adjust scissors", 92, 147)
	end
	gfx.drawText("Down: dismiss", 92, 169)

	for i = 1, 3 do
		if population_limit[i] > POPULATION_COUNT then
			population_limit[i] = POPULATION_COUNT
		elseif population_limit[i] < 1 then
			population_limit[i] = 1
		end
	end
end

-- Mode selection screen, waiting for player to select game mode.
local function game_select()
	reset_requested = false

	gfx.clear()

	-- Draw animated instruction image.
	game_select_frame[1] = (game_select_frame[1] + 1) & 0xff
	if player_kind == KIND_ROCK then
		-- Allocate buffer for scratch image on first use.  Playdate's SDK
		-- overs a drawSampled function for tilting against the X axis, but
		-- we want to tilt against the Y axis as well.  This is done by
		-- rotating the input image, tilt it, and then rotate the tilted
		-- result back for drawing.
		if not game_select_scratch then
			game_select_rotated_console = console_images:getImage(1):rotatedImage(90)
			game_select_scratch = gfx.image.new(158, 158)
		end

		-- Draw inverted selection rectangle.  Basically we draw a rectangle
		-- over everything except rocks, the end result is that the rocks get
		-- highlighted with a white background while the background for
		-- everything else is slightly dimmed.
		--
		-- The fill pattern here draws 2 dots for every 4x4 square:
		--
		--   #... 0x7
		--   .... 0xf
		--   ..#. 0xd
		--   .... 0xf
		--
		-- We use the exact same pattern in all three places in this function.
		-- Because Playdate's fill patterns are aligned to screen coordinates,
		-- all dots will come out aligned despite the rectangle coordinates
		-- not being aligned.
		gfx.setPattern({0x77, 0xff, 0xdd, 0xff, 0x77, 0xff, 0xdd, 0xff})
		gfx.fillRect(0, 50, 400, 190)

		-- Draw tilting console.
		local angle
		if (game_select_frame[1] & 16) == 0 then
			angle = game_select_frame[1] & 15
		else
			angle = 16 - (game_select_frame[1] & 15)
		end
		angle *= 0.12

		local f <const> = (game_select_frame[1] >> 5) & 3
		if f == 0 then
			-- Tilt up.
			local image <const> = console_images:getImage(1)
			image:drawSampled(
				121, 66, 158, 158,  -- x, y, w, h
				0.5, 0.5,  -- cx, cy
				1, 0,      -- dxx, dyx
				0, 1,      -- dxy, dyy
				0.5, 0.5,  -- dx, dy
				24,        -- z
				angle,     -- tilt angle
				false)     -- tile
		elseif f == 1 then
			-- Tilt right.
			gfx.pushContext(game_select_scratch)
				gfx.clear(gfx.kColorClear)
				game_select_rotated_console:drawSampled(
					0, 0, 158, 158,  -- x, y, w, h
					0.5, 0.5,  -- cx, cy
					1, 0,      -- dxx, dyx
					0, 1,      -- dxy, dyy
					0.5, 0.5,  -- dx, dy
					24,        -- z
					-angle,    -- tilt angle
					false)     -- tile
			gfx.popContext()
			game_select_scratch:drawRotated(200, 144, -90)
		elseif f == 2 then
			-- Tilt down.
			local image <const> = console_images:getImage(1)
			image:drawSampled(
				121, 66, 158, 158,  -- x, y, w, h
				0.5, 0.5,  -- cx, cy
				1, 0,      -- dxx, dyx
				0, 1,      -- dxy, dyy
				0.5, 0.5,  -- dx, dy
				24,        -- z
				-angle,    -- tilt angle
				false)     -- tile
		else
			-- Tilt left.
			gfx.pushContext(game_select_scratch)
				gfx.clear(gfx.kColorClear)
				game_select_rotated_console:drawSampled(
					0, 0, 158, 158,  -- x, y, w, h
					0.5, 0.5,  -- cx, cy
					1, 0,      -- dxx, dyx
					0, 1,      -- dxy, dyy
					0.5, 0.5,  -- dx, dy
					24,        -- z
					angle,     -- tilt angle
					false)     -- tile
			gfx.popContext()
			game_select_scratch:drawRotated(200, 144, -90)
		end

		-- 4 = "Tilt to move", 132 pixels.
		text_images:drawImage(4, 134, 50)

	elseif player_kind == KIND_PAPER then
		-- Draw inverted selection rectangle.
		gfx.setPattern({0x77, 0xff, 0xdd, 0xff, 0x77, 0xff, 0xdd, 0xff})
		gfx.fillRect(100, 0, 300, 240)

		-- Draw dots over D-Pad.
		console_images:drawImage(1, 104, 76)
		gfx.setColor(gfx.kColorBlack)
		local f <const> = (game_select_frame[1] >> 3) & 3
		if f == 0 then
			gfx.fillRect(160, 161, 4, 4)
		elseif f == 1 then
			gfx.fillRect(171, 172, 4, 4)
		elseif f == 2 then
			gfx.fillRect(160, 183, 4, 4)
		else
			gfx.fillRect(149, 172, 4, 4)
		end

		-- 5 = "Move with D-PaD", 171 pixels.
		text_images:drawImage(5, 115, 50)

	elseif player_kind == KIND_SCISSORS then
		-- Draw inverted selection rectangle.
		gfx.setPattern({0x77, 0xff, 0xdd, 0xff, 0x77, 0xff, 0xdd, 0xff})
		gfx.fillRect(0, 0, 300, 240)

		-- Draw console images with crank.
		local f <const> = ((game_select_frame[1] >> 1) & 7) + 2
		console_images:drawImage(f, 104, 76)

		-- 6 = "Turn with crank", 173 pixels.
		text_images:drawImage(6, 114, 50)

	else
		-- 3 =  "Spectate", 91 pixels.
		text_images:drawImage(3, 155, 112)
	end

	-- Update group animation frames based on currently selected mode.
	if player_kind == KIND_ROCK then
		game_select_frame[2] = (game_select_frame[2] + 1) & 0xff
	elseif player_kind == KIND_PAPER then
		game_select_frame[3] = (game_select_frame[3] + 1) & 0xff
	elseif player_kind == KIND_SCISSORS then
		game_select_frame[4] = (game_select_frame[4] + 1) & 0xff
	else
		game_select_frame[2] = (game_select_frame[2] + 1) & 0xff
		game_select_frame[3] = (game_select_frame[3] + 1) & 0xff
		game_select_frame[4] = (game_select_frame[4] + 1) & 0xff
	end

	-- Draw rocks.
	for i = 1, 5 do
		local f <const> = game_select_frame[2]
		local p <const> = (f >> 5) & 3
		local a, y
		if accelerometer_test_timer < INPUT_TEST_TIMER then
			-- Draw rocks moving in alternating directions.
			if p == 0 then
				-- Move down.
				a = 4
				y = (f >> 1) & 15
			elseif p == 1 then
				-- Rotate up.
				a = 4 - ((f >> 2) & 7)
				y = 16
			elseif p == 2 then
				-- Move up.
				a = -4
				y = 16 - ((f >> 1) & 15)
			else
				-- Rotate down.
				a = -4 + ((f >> 2) & 7)
				y = 0
			end
			if (i & 1) == 0 then
				a = ((a + 32) & 31) + 1
			else
				-- Alternate position and heading angle on every other rock.
				a = ((32 - a) & 31) + 1
				y = 16 - y
			end
		else
			-- Draw rocks to match the direction set by accelerometer_test.
			a = example_direction
			y = 8
		end

		sprites32:drawImage(
			animation_frame[KIND_ROCK][STATE_LIVE][a][((f + i * 3) & 15) + 1],
			64 + i * 40,
			y)
	end

	-- Draw papers.
	for i = 1, 5 do
		local f <const> = game_select_frame[3]
		local p <const> = (f >> 5) & 3
		local a
		if p == 0 then
			-- Tilt down.
			a = 2
		elseif p == 1 then
			-- Rotate up.
			a = 2 - ((f >> 3) & 3)
		elseif p == 2 then
			-- Tilt up.
			a = -2
		else
			-- Rotate down.
			a = -2 + ((f >> 3) & 3)
		end
		a = ((a + 32) & 31) + 1

		sprites32:drawImage(
			animation_frame[KIND_PAPER][STATE_LIVE][a][((f + i * 3) & 15) + 1],
			(i & 1) * 32,
			164 - i * 20)
	end

	-- Draw scissors.
	local scissors_positions <const> = {1, 7, 13, 20, 26, 1}
	local scissors_angles_minus_1 <const> = {11, 16, 23, 29, 4}
	for i = 1, 5 do
		local f <const> = game_select_frame[4]
		local a, x, y
		if crank_test_timer < INPUT_TEST_TIMER then
			-- Draw scissors running in circles.
			if (f & 15) < 8 then
				-- Interpolate position.
				local v0 <const> = average_velocity[scissors_positions[i]]
				local x0 <const> = ((332 << 8) + v0[1] * 12)
				local y0 <const> = ((120 << 8) + v0[2] * 12)

				local v1 <const> = average_velocity[scissors_positions[i + 1]]
				local x1 <const> = ((332 << 8) + v1[1] * 12)
				local y1 <const> = ((120 << 8) + v1[2] * 12)

				x = (x0 + (((x1 - x0) * (f & 7)) // 8)) >> 8
				y = (y0 + (((y1 - y0) * (f & 7)) // 8)) >> 8
				a = (scissors_angles_minus_1[i] & 31) + 1
			else
				-- Interpolate angle.
				local v <const> = average_velocity[scissors_positions[i]]
				x = ((332 << 8) + v[1] * 12) >> 8
				y = ((120 << 8) + v[2] * 12) >> 8

				local a0 <const> = scissors_angles_minus_1[(i - 1 + 4) % 5 + 1]
				local a1 = scissors_angles_minus_1[i]
				if a1 < a0 then
					a1 += 32
				end
				a = ((a0 + ((a1 - a0) * (f & 7)) // 8) & 31) + 1
			end
		else
			-- Draw scissors to match the direction set by crank_test.
			local v <const> = average_velocity[scissors_positions[i]]
			x = ((332 << 8) + v[1] * 12) >> 8
			y = ((120 << 8) + v[2] * 12) >> 8
			a = example_direction
		end

		sprites32:drawImage(
			animation_frame[KIND_SCISSORS][STATE_LIVE][a][(f & 15) + 1],
			x,
			y)
	end

	-- (+) (space) Select (space) (A) (space) Start
	-- 16  2       71     16      16  2       57    = 180 pixels.
	misc2_images:drawImage(11, 110, 220)
	text_images:drawImage(1, 128, 220)
	misc2_images:drawImage(9, 215, 220)
	text_images:drawImage(2, 233, 220)

	-- Start a new game when A or B is pressed.
	if playdate.buttonJustPressed(playdate.kButtonA) or
	   playdate.buttonJustPressed(playdate.kButtonB) then
		-- Start init_world_thread if it hasn't started already.
		async_init_world()

		-- Wait for world initialization to complete.
		game_state = game_init
		return
	end

	-- Check player input to set game mode.
	--
	-- Also dismiss test windows when direction buttons are pressed.
	-- Accelerometer and crank test can be dismissed with any direction,
	-- population must be dismissed with "down" button.
	if playdate.buttonJustPressed(playdate.kButtonUp) then
		player_kind = KIND_ROCK
		accelerometer_test_timer = 0
		crank_test_timer = 0
	elseif playdate.buttonJustPressed(playdate.kButtonLeft) then
		player_kind = KIND_PAPER
		accelerometer_test_timer = 0
		crank_test_timer = 0
	elseif playdate.buttonJustPressed(playdate.kButtonRight) then
		player_kind = KIND_SCISSORS
		accelerometer_test_timer = 0
		crank_test_timer = 0
	elseif playdate.buttonJustPressed(playdate.kButtonDown) then
		player_kind = 0
		accelerometer_test_timer = 0
		crank_test_timer = 0
		population_test_timer = 0
	end
	accelerometer_test()
	crank_test()
	population_test()

	-- Initialize the next game in the background.  Note that all game_*()
	-- functions do this, and they all do it at the end of the game state,
	-- since we want to use only the spare cycles at the end of each game
	-- state to do the initialization.
	async_init_world()
end

-- Draw buttons text and handle button press for game_completed and game_over.
local function handle_end_game_action()
	-- (B) (space) Menu (space) (A) (space) New game
	-- 16  2       54   16      16  2       103      = 209 pixels.
	misc2_images:drawImage(10, 95, 208)
	text_images:drawImage(9, 113, 208)
	misc2_images:drawImage(9, 183, 208)
	text_images:drawImage(8, 201, 208)

	-- Start new game when A button is pressed.
	if playdate.buttonJustPressed(playdate.kButtonA) then
		game_state = game_init
		game_in_progress = false
	end

	-- Return to mode selection when B button is pressed.
	if playdate.buttonJustPressed(playdate.kButtonB) then
		if player_kind == KIND_ROCK then
			playdate.stopAccelerometer()
		end
		game_state = game_select
		game_in_progress = false
	end
end

-- Game completed because one object kind (possibly controlled by player)
-- is the only surviving group.
local function game_completed()
	assert(live_kind_count() == 1)
	run_game_step()

	-- Show which group has won.
	if live_count[KIND_ROCK] > 0 then
		assert(live_count[KIND_PAPER] == 0)
		assert(live_count[KIND_SCISSORS] == 0)
		-- 11 = "Rock wins", 103 pixels.
		text_images:drawImage(11, 149, 80)
	elseif live_count[KIND_PAPER] > 0 then
		assert(live_count[KIND_SCISSORS] == 0)
		-- 12 = "Paper wins", 113 pixels.
		text_images:drawImage(12, 144, 80)
	else
		assert(live_count[KIND_SCISSORS] > 0)
		-- 13 = "Scissors wins", 140 pixels.
		text_images:drawImage(13, 130, 80)
	end

	-- Handle A/B buttons.
	handle_end_game_action()

	-- Automatically start next game in spectator mode.
	if player_kind == 0 then
		next_game_countdown_frames -= 1
		if next_game_countdown_frames < 150 then
			-- Start next game when countdown has expired.
			if next_game_countdown_frames == 0 then
				game_state = game_init
				game_in_progress = false
				return
			end

			-- 14 = "Next game in", 135 pixels.
			--
			-- Note that the horizontal position below includes an extra
			-- 34 pixels to account for the count.
			text_images:drawImage(14, 116, 32)

			-- 15..19 = count, 23..27 pixels.
			local count_image <const> = 15 + (next_game_countdown_frames // 30)
			text_images:drawImage(count_image, 258, 32)
		end
	end

	-- Initialize the next game in the background while waiting for player
	-- to press a button.
	async_init_world()
end

-- Game over because all objects controlled by player has been killed.
--
-- The game will wait for a button press to proceed.
local function game_over()
	assert(live_kind_count() < 3)
	run_game_step()

	-- Show game over text.
	-- 10 = "Game over", 111 pixels.
	text_images:drawImage(10, 145, 100)

	-- Handle A/B buttons.
	handle_end_game_action()

	-- Initialize the next game in the background while waiting for player
	-- to press a button.
	async_init_world()
end

-- Main game loop.
game_loop = function()
	run_game_step()

	if player_kind ~= 0 and live_count[player_kind] == 0 then
		assert(debug_log("Game over after " .. game_steps .. " steps"))
		assert(debug_count_report())
		game_state = game_over
		if player_kind == KIND_ROCK then
			playdate.stopAccelerometer()
		end
		return
	end

	if live_kind_count() == 1 then
		assert(debug_log("Game completed in " .. game_steps .. " steps"))
		assert(debug_count_report())
		game_state = game_completed
		next_game_countdown_frames = 240
		return
	end

	if playdate.buttonJustPressed(playdate.kButtonA) then
		next_live_object(1)
		assert(debug_log(string.format("follow_index=%d", follow_index)))
	end
	if playdate.buttonJustPressed(playdate.kButtonB) then
		next_live_object(-1)
		assert(debug_log(string.format("follow_index=%d", follow_index)))
	end

	-- Initialize the next game in the background when the population gets
	-- sufficiently low, since we would have the spare CPU cycles for it.
	if live_count[KIND_ROCK] + live_count[KIND_PAPER] + live_count[KIND_SCISSORS] <= 20 then
		async_init_world()
	end
end

game_state = game_select

-- Add menu option to recalibrate accelerometer.
playdate.getSystemMenu():addMenuItem("zero tilt", function()
	if not playdate.accelerometerIsRunning() then
		playdate.startAccelerometer()
	end
	accelerometer_dx, accelerometer_dy, accelerometer_dz = playdate.readAccelerometer()
	assert(debug_log(string.format("new zero=(%f, %f, %f)", accelerometer_dx, accelerometer_dy, accelerometer_dz)))
end)

-- Add menu option to return to game mode selection screen.
--
-- Since menu cursor starts with "volume" selected, placing the "reset"
-- option last makes it faster to reach than the "zero tilt" option.
playdate.getSystemMenu():addMenuItem("reset", function()
	game_state = game_select
	game_in_progress = false
	reset_requested = true
	playdate.stopAccelerometer()
end)

assert(debug_log("Initialized"))

-- Playdate callbacks.
function playdate.update()
	frame_start_time = playdate.getElapsedTime()
	game_state()
	assert(debug_frame_rate())
end

function playdate.gameWillPause()
	if not menu_image then
		menu_image = gfx.image.new(400, 240, gfx.kColorWhite)
	end

	gfx.pushContext(menu_image)
		gfx.clear()

		if game_state == game_select then
			gfx.drawText("*A/B*: Start game", 4, 4)
			gfx.drawText("*D-Pad*: Select mode", 4, 26)
		elseif game_state == game_loop then
			if player_kind == KIND_ROCK then
				gfx.drawText("*Tilt*: Move", 4, 4)
				gfx.drawText("*A*: Next rock", 4, 26)
				gfx.drawText("*B*: Previous rock", 4, 48)
			elseif player_kind == KIND_PAPER then
				gfx.drawText("*D-Pad*: Move", 4, 4)
				gfx.drawText("*A*: Next paper", 4, 26)
				gfx.drawText("*B*: Previous paper", 4, 48)
			elseif player_kind == KIND_SCISSORS then
				gfx.drawText("*Crank*: Set direction", 4, 4)
				gfx.drawText("*A*: Next scissors", 4, 26)
				gfx.drawText("*B*: Previous scissors", 4, 48)
			else  -- Spectator mode.
				gfx.drawText("*A*: Next object", 4, 4)
				gfx.drawText("*B*: Previous object", 4, 26)
			end
		elseif game_state == game_completed or game_state == game_over then
			gfx.drawText("*A*: New game", 4, 4)
			gfx.drawText("*B*: Menu", 4, 26)
		end
		gfx.drawText(playdate.metadata.name .. " v" .. playdate.metadata.version, 4, 198)
		gfx.drawText("omoikane@uguu.org", 4, 220)
	gfx.popContext()
	playdate.setMenuImage(menu_image)
end

--}}}
