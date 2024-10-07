/* Generate test map using floor tiles.

   Usage:

      ./generate_test_floor_map.c {input-tile-table.png} {output.png}
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
#define TILE_SIZE          64
#define TILE_IMAGE_WIDTH   (TILE_SIZE * 16)
#define TILE_IMAGE_HEIGHT  (TILE_SIZE * 16)

/* Output map size in tiles. */
#define MAP_WIDTH       16
#define MAP_HEIGHT      9
#define IMAGE_WIDTH     (MAP_WIDTH * TILE_SIZE)
#define IMAGE_HEIGHT    (MAP_HEIGHT * TILE_SIZE)

/* Pre-allocated buffers for pixel data. */
static uint8_t tile_pixels[TILE_IMAGE_WIDTH * TILE_IMAGE_HEIGHT * 2];
static uint8_t output_pixels[IMAGE_WIDTH * IMAGE_HEIGHT * 2];

/* A single row of map cell data. */
static int previous_row[MAP_WIDTH];

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

/* Generate map tiles. */
static void GenerateMap()
{
   int x, y, previous_cell, cell;

   /* Generate a random invisible row. */
   for(x = 0; x < MAP_WIDTH; x++)
      previous_row[x] = rand() & 0xff;

   /* Generate rows. */
   for(y = 0; y < MAP_HEIGHT; y++)
   {
      /* Generate an invisible tile, which serves as the previous tile
         to the left of the first tile in this row.                    */
      previous_cell = rand() & 0xff;
      for(x = 0; x < MAP_WIDTH; x++)
      {
         /* Tile image indices follow this convention:
                     +-----+
                     |     |
                     |    1|
                     |  0  |
                     +-----+
            +-----+  +-----+
            |     |  |  6  |  Bit 6 of new tile is bit 0 from tile above.
            |    1|  |7 ?  |  Bit 7 of new tile is bit 1 from tile to the left.
            |  0  |  |     |  Bits 0..5 are random.
            +-----+  +-----+
         */
         cell = ((previous_cell & 2) << 6) |
                ((previous_row[x] & 1) << 6) |
                (rand() & 0x3f);
         WriteTile(cell, x * TILE_SIZE, y * TILE_SIZE);

         previous_row[x] = cell;
         previous_cell = cell;
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

   /* Generate map tiles. */
   GenerateMap();

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
