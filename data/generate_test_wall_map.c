/* Generate test map using tiles produced by generate_wall_tiles.c

   Usage:

      ./generate_test_wall_map.c {input-tile-table.png} {output.png}

   This code uses the cave generation algorithm from here:
   https://www.roguebasin.com/index.php/Cellular_Automata_Method_for_Generating_Random_Cave-Like_Levels

   To ensure that all open areas are connected, we do a floodfill from the
   center, and then close off all areas that weren't touched by the flood
   fill.  The floodfill step also has some extra tweaks to ensure that most
   pathways fulfill minimum width requirements.

   This code is meant as a prototype for the wall generation scheme that is
   used the game, but ultimately we implemented a simpler version without
   the floodfill tweaks.  The extra tweaks made generating the maps
   expensive, which we might have been able to amortize (e.g. by generating
   the map in the background using spare cycles), but actually making use of
   the special features of the map was also expensive.  Basically we need
   proper path finding to make use of the fact that all map areas are
   connected, and playdate doesn't quite have the CPU to do path finding
   with the number of objects we have simulated.

   It was much simpler to just make the walls breakable such that the
   objects can eventually make a path to wherever they want to go.
*/

#include<png.h>
#include<stdint.h>
#include<stdio.h>
#include<stdlib.h>
#include<string.h>
#include<time.h>
#include<unistd.h>

#ifdef _WIN32
   #include<fcntl.h>
   #include<io.h>
#endif

/* Tile size in pixels. */
#define TILE_SIZE          8
#define TILE_IMAGE_WIDTH   (TILE_SIZE * 16)
#define TILE_IMAGE_HEIGHT  (TILE_SIZE * 9)

/* Bits where tile variations are encoded. */
#define VARIATION_MASK     0x70

/* Index of solid wall tile. */
#define WALL_TILE_INDEX    0x80

/* Output map size in tiles. */
#define MAP_WIDTH       160
#define MAP_HEIGHT      160
#define IMAGE_WIDTH     (MAP_WIDTH * TILE_SIZE)
#define IMAGE_HEIGHT    (MAP_HEIGHT * TILE_SIZE)

/* Pre-allocated buffers for pixel data. */
static uint8_t tile_pixels[TILE_IMAGE_WIDTH * TILE_IMAGE_HEIGHT * 2];
static uint8_t output_pixels[IMAGE_WIDTH * IMAGE_HEIGHT * 2];

/* Map data.  1=wall, 0=empty. */
static uint8_t map_data[MAP_HEIGHT][MAP_WIDTH];
#define MAP_DATA(x, y)  \
   ( (x) < 0 || (x) >= MAP_WIDTH || (y) < 0 || (y) >= MAP_HEIGHT  \
     ? 1 : map_data[y][x] )

/* Stack of XY coordinates, for use with FillMapHoles. */
typedef struct { int x, y; } XY;
typedef struct
{
   XY *s;
   int size, capacity;
} VisitStack;

/* Push item onto stack. */
static void Push(VisitStack *stack, int x, int y)
{
   if( stack->size >= stack->capacity )
   {
      if( stack->capacity == 0 )
      {
         stack->capacity = 16;
      }
      else
      {
         stack->capacity *= 2;
      }
      stack->s = realloc(stack->s, stack->capacity * sizeof(XY));
      if( stack->s == NULL )
      {
         printf("Not enough memory for %d elements\n", stack->capacity);
         exit(EXIT_FAILURE);
      }
   }
   stack->s[stack->size].x = x;
   stack->s[stack->size].y = y;
   stack->size++;
}

/* Pop top item off of the stack. */
static void Pop(VisitStack *stack, int *x, int *y)
{
   stack->size--;
   *x = stack->s[stack->size].x;
   *y = stack->s[stack->size].y;
}

/* Syntactic sugar. */
static void Destroy(VisitStack *stack)
{
   free(stack->s);
   memset(stack, 0, sizeof(VisitStack));
}

/* Populate cells with random values. */
static void GenerateRandomMapCells()
{
   int x, y;

   for(y = 0; y < MAP_HEIGHT; y++)
   {
      for(x = 0; x < MAP_WIDTH; x++)
         map_data[y][x] = ((float)rand() / (float)RAND_MAX) < 0.45 ? 1 : 0;
   }
}

/* Iteratively apply smoothing to map data. */
static void SmoothMapCells()
{
   uint8_t *buffer, *p;
   int x, y, i, count;

   buffer = (uint8_t*)malloc(MAP_WIDTH * MAP_HEIGHT);
   if( buffer == NULL )
   {
      puts("Out of memory");
      exit(EXIT_FAILURE);
   }
   for(i = 0; i < 4; i++)
   {
      /* Compute new map cells from existing map cells. */
      p = buffer;
      for(y = 0; y < MAP_HEIGHT; y++)
      {
         for(x = 0; x < MAP_WIDTH; x++, p++)
         {
            count = MAP_DATA(x - 1, y - 1) +
                    MAP_DATA(x,     y - 1) +
                    MAP_DATA(x + 1, y - 1) +
                    MAP_DATA(x - 1, y    ) +
                    MAP_DATA(x,     y    ) +
                    MAP_DATA(x + 1, y    ) +
                    MAP_DATA(x - 1, y + 1) +
                    MAP_DATA(x,     y + 1) +
                    MAP_DATA(x + 1, y + 1);
            *p = (count <= 4 ? 0 : 1);
         }
      }

      /* Overwrite the old map data with new data.  A more efficient
         approach would be to have a double-buffered approach to avoid
         copying after each iteration, but for this test program, we
         just want to do what's convenient.                            */
      memcpy(&map_data[0][0], buffer, MAP_WIDTH * MAP_HEIGHT);
   }
   free(buffer);
}

/* Seal off inaccessible areas.  Returns 0 on success. */
static void FillMapHoles()
{
   static const XY offsets[8] =
   {
      {1, 0}, {0, 1}, {-1, 0}, {0, -1}, {1, 1}, {-1, 1}, {-1, -1}, {1, -1}
   };
   VisitStack fill_stack;
   uint8_t *accessible_spots, *p;
   int x, y, i;

   memset(&fill_stack, 0, sizeof(VisitStack));

   /* Carve out a 3x3 space at the center of the map.  We will start
      the flood fill process from there.                             */
   x = MAP_WIDTH / 2;
   y = MAP_HEIGHT / 2;
   map_data[y - 1][x - 1] = 0;
   map_data[y - 1][x    ] = 0;
   map_data[y - 1][x + 1] = 0;
   map_data[y    ][x - 1] = 0;
   map_data[y    ][x    ] = 0;
   map_data[y    ][x + 1] = 0;
   map_data[y + 1][x - 1] = 0;
   map_data[y + 1][x    ] = 0;
   map_data[y + 1][x + 1] = 0;
   Push(&fill_stack, x, y);

   accessible_spots = (uint8_t*)calloc(MAP_WIDTH * MAP_HEIGHT, 1);
   if( accessible_spots == NULL )
   {
      puts("Out of memory");
      exit(EXIT_FAILURE);
   }

   /* Apply flood fill with a thick brush, marking accessible cells with
      two bits:
      1 = current cell is accessible.  If this bit is set, it means this
          cell is at the center of an empty 3x3 space.
      2 = neighboring cell is accessible.

      Typical flood fills operate a pixel at a time, which is the same as
      painting an area with an 1x1 brush.  Because we need wider space to
      guarantee accessibility, we paint with a 3x3 brush, and only mark a
      cell if it's the center of an empty 3x3 space.

      Because we are using a wider brush, the usual 1-bit-per-cell scheme
      for tracking is not sufficient -- we need a bit to track cells that
      have been visited, plus one separate bit to track cells that are
      neighbors of the visited cell.                                      */
   while( fill_stack.size > 0 )
   {
      /* Mark newly accessible spot. */
      Pop(&fill_stack, &x, &y);
      if( (accessible_spots[y * MAP_WIDTH + x] & 1) != 0 )
         continue;
      accessible_spots[y * MAP_WIDTH + x] = 1;
      #define MARK_ACCESSIBLE_NEIGHBOR(x, y)  \
         if( (x) >= 0 && (x) < MAP_WIDTH &&                 \
             (y) >= 0 && (y) < MAP_HEIGHT )                 \
         {                                                  \
            accessible_spots[(y) * MAP_WIDTH + (x)] |= 2;   \
         }
      MARK_ACCESSIBLE_NEIGHBOR(x + 1, y    )
      MARK_ACCESSIBLE_NEIGHBOR(x + 1, y + 1)
      MARK_ACCESSIBLE_NEIGHBOR(x,     y + 1)
      MARK_ACCESSIBLE_NEIGHBOR(x - 1, y + 1)
      MARK_ACCESSIBLE_NEIGHBOR(x - 1, y    )
      MARK_ACCESSIBLE_NEIGHBOR(x - 1, y - 1)
      MARK_ACCESSIBLE_NEIGHBOR(x,     y - 1)
      MARK_ACCESSIBLE_NEIGHBOR(x + 1, y - 1)
      #undef MARK_ACCESSIBLE_NEIGHBOR

      for(i = 0; i < 8; i++)
      {
         if( MAP_DATA(x + offsets[i].x, y + offsets[i].y) == 0 &&
             MAP_DATA(x + offsets[i].x + 1, y + offsets[i].y    ) == 0 &&
             MAP_DATA(x + offsets[i].x + 1, y + offsets[i].y + 1) == 0 &&
             MAP_DATA(x + offsets[i].x,     y + offsets[i].y + 1) == 0 &&
             MAP_DATA(x + offsets[i].x - 1, y + offsets[i].y + 1) == 0 &&
             MAP_DATA(x + offsets[i].x - 1, y + offsets[i].y    ) == 0 &&
             MAP_DATA(x + offsets[i].x - 1, y + offsets[i].y - 1) == 0 &&
             MAP_DATA(x + offsets[i].x,     y + offsets[i].y - 1) == 0 &&
             MAP_DATA(x + offsets[i].x + 1, y + offsets[i].y - 1) == 0 )
         {
            Push(&fill_stack, x + offsets[i].x, y + offsets[i].y);
         }
      }
   }
   Destroy(&fill_stack);

   /* Find all inaccessible spots that have exactly one orthogonal empty
      neighbor, and mark those accessible.  Those are in fact not
      accessible, but we want to leave those single cell holes open
      because they make the map look more interesting.                   */
   p = accessible_spots;
   for(y = 0; y < MAP_HEIGHT; y++)
   {
      for(x = 0; x < MAP_WIDTH; x++, p++)
      {
         if( map_data[y][x] == 0 && *p == 0 &&
             MAP_DATA(x + 1, y    ) +
             MAP_DATA(x,     y + 1) +
             MAP_DATA(x - 1, y    ) +
             MAP_DATA(x,     y - 1) == 3 )
         {
            *p = 1;
         }
      }
   }

   /* Fill all empty spots that are not accessible. */
   p = accessible_spots;
   for(y = 0; y < MAP_HEIGHT; y++)
   {
      for(x = 0; x < MAP_WIDTH; x++, p++)
      {
         if( map_data[y][x] == 0 && *p == 0 )
            map_data[y][x] = 1;
      }
   }

   free(accessible_spots);
}

/* Populate map_data with generated map data. */
static void GenerateMapCells()
{
   GenerateRandomMapCells();
   SmoothMapCells();
   FillMapHoles();
}

/* Write tile to specified position in output_pixels. */
static void WriteTile(int tile_index, int x, int y)
{
   png_bytep p, q;
   const int ty = (tile_index >> 4) * TILE_SIZE;
   const int tx = (tile_index & 15) * TILE_SIZE;
   int u, v;

   for(u = 0; u < TILE_SIZE; u++)
   {
      p = tile_pixels + ((ty + u) * TILE_IMAGE_WIDTH + tx) * 2;
      q = output_pixels + ((y + u) * IMAGE_WIDTH + x) * 2;
      for(v = 0; v < TILE_SIZE; v++, p += 2, q += 2)
      {
         if( p[1] != 0 )
         {
            q[0] = p[0];
            q[1] = p[1];
         }
      }
   }
}

/* Convert map_data into pixel data and write them to output_pixels. */
static void GenerateMapPixels()
{
   int x, y, tile_index;

   for(y = 0; y < MAP_HEIGHT; y++)
   {
      for(x = 0; x < MAP_WIDTH; x++)
      {
         if( map_data[y][x] )
         {
            tile_index = WALL_TILE_INDEX;
         }
         else
         {
            tile_index = (MAP_DATA(x + 1, y    ) << 0) |
                         (MAP_DATA(x,     y + 1) << 1) |
                         (MAP_DATA(x - 1, y    ) << 2) |
                         (MAP_DATA(x,     y - 1) << 3) |
                         (rand() & VARIATION_MASK);
         }
         WriteTile(tile_index, x * TILE_SIZE, y * TILE_SIZE);
      }
   }
}

int main(int argc, char **argv)
{
   png_image tiles_image, output_image;

   if( argc != 3 )
      return printf("%s {input-tile-table.png} {output.png}\n", *argv);

   if( strcmp(argv[2], "-") == 0 && isatty(STDOUT_FILENO) )
   {
      fputs("Not writing output to stdout because it's a tty\n", stderr);
      return 1;
   }
   #ifdef _WIN32
      setmode(STDOUT_FILENO, O_BINARY);
   #endif

   srand(time(NULL));

   /* Load tile image. */
   memset(&tiles_image, 0, sizeof(tiles_image));
   tiles_image.version = PNG_IMAGE_VERSION;
   if( !png_image_begin_read_from_file(&tiles_image, argv[1]) )
      return printf("Error reading %s\n", argv[1]);
   tiles_image.format = PNG_FORMAT_GA;
   if( tiles_image.width != TILE_IMAGE_WIDTH ||
       tiles_image.height != TILE_IMAGE_HEIGHT )
   {
      printf("Unexpected tile image size: expected %d,%d, got %d,%d\n",
             TILE_IMAGE_WIDTH, TILE_IMAGE_HEIGHT,
             (int)tiles_image.width, (int)tiles_image.height);
      return 1;
   }
   if( !png_image_finish_read(&tiles_image, NULL, tile_pixels, 0, NULL) )
      return printf("Error loading %s\n", argv[1]);

   /* Create map image. */
   memset(&output_image, 0, sizeof(output_image));
   output_image.version = PNG_IMAGE_VERSION;
   output_image.format = PNG_FORMAT_GA;
   output_image.width = IMAGE_WIDTH;
   output_image.height = IMAGE_HEIGHT;

   /* Initialize output image to be all opaque white pixels.
      Wall tiles (with transparent bits) will be drawn on top of this. */
   memset(output_pixels, 0xff, IMAGE_WIDTH * IMAGE_HEIGHT * 2);

   /* Generate map. */
   GenerateMapCells();
   GenerateMapPixels();

   /* Write output. */
   if( strcmp(argv[2], "-") == 0 )
   {
      if( !png_image_write_to_stdio(
             &output_image, stdout, 0, output_pixels, 0, NULL) )
      {
         fputs("Error writing to stdout\n", stderr);
         return 1;
      }
   }
   else
   {
      if( !png_image_write_to_file(
             &output_image, argv[2], 0, output_pixels, 0, NULL) )
      {
         printf("Error writing %s\n", argv[2]);
         return 1;
      }
   }
   return 0;
}
