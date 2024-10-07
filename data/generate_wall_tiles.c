/* Generate wall tile images.

   Usage:

      ./generate_wall_tiles {output.png}

   Use "-" to write output to stdout.

   Output tiles 0x00..0x0f are indexed by 4 bits:

      +---+---+---+
      |   | 3 |   |
      +---+---+---+
      | 2 |   | 0 |
      +---+---+---+
      |   | 1 |   |
      +---+---+---+

   Where each 1 bit indicates that the corresponding neighbor in that cell
   is a wall, assuming that the current cell is empty.

   Output tiles 0x10..0x7f are variations of 0x00..0x0f.

   Tile 0x80 is a solid wall tile.

   Note that this indexing scheme only takes the 4 orthogonal neighbors
   into account.  We are able to get reasonably smooth walls with this
   scheme, and didn't need to look at the 4 diagonal neighbors.  We
   actually did try to check the 4 diagonal neighbors and adjust the output
   tile accordingly, but there just isn't enough detail in 8x8 tiles to
   make those variations worthwhile.
*/

#include<png.h>
#include<stdio.h>
#include<stdlib.h>
#include<string.h>
#include<unistd.h>

#ifdef _WIN32
   #include<fcntl.h>
   #include<io.h>
#endif

/* Tile size in pixels. */
#define TILE_SIZE     8

/* Output tile table image size in pixels. */
#define IMAGE_WIDTH   (TILE_SIZE * 16)
#define IMAGE_HEIGHT  (TILE_SIZE * 9)

/* Draw solid black pixels onto a rectangular area. */
static void Rect(png_bytep pixels, int x, int y, int w, int h)
{
   int ix, iy;
   png_bytep p;

   for(iy = 0; iy < h; iy++)
   {
      /* The color part of each pixel is already black, so we only need to
         set the alpha of each pixel to maximum opacity.  Here we set the
         pointer to point at the first alpha byte in each scanline.        */
      p = pixels + ((y + iy) * IMAGE_WIDTH + x) * 2 + 1;
      for(ix = 0; ix < w; ix++, p += 2)
         *p = 0xff;
   }
}

/* Add tiles following indexing scheme described at the top of this file. */
static void AddWallAdjacentTiles(png_bytep pixels)
{
   int tx, ty, x, y;

   for(ty = 0; ty < 8; ty++)
   {
      y = ty * TILE_SIZE;
      for(tx = 0; tx < 16; tx++)
      {
         x = tx * TILE_SIZE;
         if( (tx & 1) != 0 )
         {
            /* Right.
               0    1    2    3    4    5    6    7
               ..   .#   ..   .#   .#   .#   .#   .#
               .#   .#   .#   .#   .#   .#   .#   .#
               .#   .#   .#   .#   .#   ##   .#   ##
               ..   ..   ..   ..   ##   ##   ##   ##
               ..   ..   ..   ..   ##   ##   ##   ##
               .#   .#   .#   .#   .#   .#   ##   ##
               .#   .#   .#   .#   .#   .#   .#   .#
               ..   ..   .#   .#   .#   .#   .#   .#  */
            if( (ty & 1) == 0 )
            {
               Rect(pixels, x + TILE_SIZE - 1, y + 1, 1, 2);
               Rect(pixels, x + TILE_SIZE - 1, y + TILE_SIZE - 3, 1, 2);
               if( (ty & 2) != 0 )
                  Rect(pixels, x + TILE_SIZE - 1, y, 1, 1);
               if( (ty & 4) != 0 )
                  Rect(pixels, x + TILE_SIZE - 1, y + TILE_SIZE - 1, 1, 1);
            }
            else
            {
               Rect(pixels, x + TILE_SIZE - 1, y, 1, TILE_SIZE);
               Rect(pixels, x + TILE_SIZE - 2, y + 3, 1, TILE_SIZE - 6);
               if( (ty & 2) != 0 )
                  Rect(pixels, x + TILE_SIZE - 2, y + 2, 1, 1);
               if( (ty & 4) != 0 )
                  Rect(pixels, x + TILE_SIZE - 2, y + TILE_SIZE - 3, 1, 1);
            }
         }
         if( (tx & 2) != 0 )
         {
            /* Down.
               0          1          2          3
               ........   ........   ........   ........
               .##..##.   .##..###   ###..##.   ###..###

               4          5          6          7
               ...##...   ...###..   ..###...   ..####..
               ########   ########   ########   ########  */
            if( (ty & 1) == 0 )
            {
               Rect(pixels, x + 1, y + TILE_SIZE - 1, 2, 1);
               Rect(pixels, x + TILE_SIZE - 3, y + TILE_SIZE - 1, 2, 1);
               if( (ty & 2) != 0 )
                  Rect(pixels, x + TILE_SIZE - 1, y + TILE_SIZE - 1, 1, 1);
               if( (ty & 4) != 0 )
                  Rect(pixels, x, y + TILE_SIZE - 1, 1, 1);
            }
            else
            {
               Rect(pixels, x, y + TILE_SIZE - 1, TILE_SIZE, 1);
               Rect(pixels, x + 3, y + TILE_SIZE - 2, TILE_SIZE - 6, 1);
               if( (ty & 2) != 0 )
                  Rect(pixels, x + TILE_SIZE - 3, y + TILE_SIZE - 2, 1, 1);
               if( (ty & 4) != 0 )
                  Rect(pixels, x + 2, y + TILE_SIZE - 2, 1, 1);
            }
         }
         if( (tx & 4) != 0 )
         {
            /* Left.
               0    1    2    3    4    5    6    7
               ..   ..   #.   #.   #.   #.   #.   #.
               #.   #.   #.   #.   #.   #.   #.   #.
               #.   #.   #.   #.   #.   #.   ##   ##
               ..   ..   ..   ..   ##   ##   ##   ##
               ..   ..   ..   ..   ##   ##   ##   ##
               #.   #.   #.   #.   #.   ##   #.   ##
               #.   #.   #.   #.   #.   #.   #.   #.
               ..   #.   ..   #.   #.   #.   #.   #.  */
            if( (ty & 1) == 0 )
            {
               Rect(pixels, x, y + 1, 1, 2);
               Rect(pixels, x, y + TILE_SIZE - 3, 1, 2);
               if( (ty & 2) != 0 )
                  Rect(pixels, x, y + TILE_SIZE - 1, 1, 1);
               if( (ty & 4) != 0 )
                  Rect(pixels, x, y, 1, 1);
            }
            else
            {
               Rect(pixels, x, y, 1, TILE_SIZE);
               Rect(pixels, x + 1, y + 3, 1, TILE_SIZE - 6);
               if( (ty & 2) != 0 )
                  Rect(pixels, x + 1, y + TILE_SIZE - 3, 1, 1);
               if( (ty & 4) != 0 )
                  Rect(pixels, x + 1, y + 2, 1, 1);
            }
         }
         if( (tx & 8) != 0 )
         {
            /* Up.
               0          1          2          3
               .##..##.   ###..##.   .##..###   ###..###
               ........   ........   ........   ........

               4          5          6          7
               ########   ########   ########   ########
               ...##...   ..###...   ...###..   ..####..  */
            if( (ty & 1) == 0 )
            {
               Rect(pixels, x + 1, y, 2, 1);
               Rect(pixels, x + TILE_SIZE - 3, y, 2, 1);
               if( (ty & 2) != 0 )
                  Rect(pixels, x, y, 1, 1);
               if( (ty & 4) != 0 )
                  Rect(pixels, x + TILE_SIZE - 1, y, 1, 1);
            }
            else
            {
               Rect(pixels, x, y, TILE_SIZE, 1);
               Rect(pixels, x + 3, y + 1, TILE_SIZE - 6, 1);
               if( (ty & 2) != 0 )
                  Rect(pixels, x + 2, y + 1, 1, 1);
               if( (ty & 4) != 0 )
                  Rect(pixels, x + TILE_SIZE - 3, y + 1, 1, 1);
            }
         }

         if( (tx & 3) == 3 )
         {
            /* Down right. */
            Rect(pixels, x + TILE_SIZE - 1, y + TILE_SIZE - 5, 1, 1);
            Rect(pixels, x + TILE_SIZE - 2, y + TILE_SIZE - 4, 2, 1);
            Rect(pixels, x + TILE_SIZE - 3, y + TILE_SIZE - 3, 3, 1);
            Rect(pixels, x + TILE_SIZE - 4, y + TILE_SIZE - 2, 4, 1);
            Rect(pixels, x + TILE_SIZE - 5, y + TILE_SIZE - 1, 5, 1);
         }
         if( (tx & 6) == 6 )
         {
            /* Down left. */
            Rect(pixels, x, y + TILE_SIZE - 5, 1, 1);
            Rect(pixels, x, y + TILE_SIZE - 4, 2, 1);
            Rect(pixels, x, y + TILE_SIZE - 3, 3, 1);
            Rect(pixels, x, y + TILE_SIZE - 2, 4, 1);
            Rect(pixels, x, y + TILE_SIZE - 1, 5, 1);
         }
         if( (tx & 12) == 12 )
         {
            /* Up left. */
            Rect(pixels, x, y + 4, 1, 1);
            Rect(pixels, x, y + 3, 2, 1);
            Rect(pixels, x, y + 2, 3, 1);
            Rect(pixels, x, y + 1, 4, 1);
            Rect(pixels, x, y,     5, 1);
         }
         if( (tx & 9) == 9 )
         {
            /* Up right. */
            Rect(pixels, x + TILE_SIZE - 1, y + 4, 1, 1);
            Rect(pixels, x + TILE_SIZE - 2, y + 3, 2, 1);
            Rect(pixels, x + TILE_SIZE - 3, y + 2, 3, 1);
            Rect(pixels, x + TILE_SIZE - 4, y + 1, 4, 1);
            Rect(pixels, x + TILE_SIZE - 5, y,     5, 1);
         }
      }
   }
}

/* Add solid black rectangle, for use where current cell is a wall. */
static void AddSolidWallTile(png_bytep pixels)
{
   Rect(pixels, 0, IMAGE_HEIGHT - TILE_SIZE, TILE_SIZE, TILE_SIZE);
}

/* Add special debugging tiles, used for checking tile alignment.
   These are never visible in release builds.                     */
static void AddDebugTiles(png_bytep pixels)
{
   int x, y;

   /* Square with solid outline. */
   Rect(pixels, TILE_SIZE, IMAGE_HEIGHT - TILE_SIZE, TILE_SIZE, 1);
   Rect(pixels, TILE_SIZE, IMAGE_HEIGHT - 1, TILE_SIZE, 1);
   Rect(pixels, TILE_SIZE, IMAGE_HEIGHT - TILE_SIZE, 1, TILE_SIZE);
   Rect(pixels, TILE_SIZE * 2 - 1, IMAGE_HEIGHT - TILE_SIZE, 1, TILE_SIZE);

   /* Square with dotted outline. */
   for(y = 0; y < TILE_SIZE; y++)
   {
      for(x = y & 1; x < TILE_SIZE; x += 2)
      {
         if( x == 0 || y == 0 || x == TILE_SIZE - 1 || y == TILE_SIZE - 1 )
            Rect(pixels, TILE_SIZE * 2 + x, IMAGE_HEIGHT - TILE_SIZE + y, 1, 1);
      }
   }
}

int main(int argc, char **argv)
{
   png_image image;
   png_bytep pixels;

   if( argc != 2 )
      return printf("%s {output.png}\n", *argv);
   if( strcmp(argv[1], "-") == 0 && isatty(STDOUT_FILENO) )
   {
      fputs("Not writing output to stdout because it's a tty\n", stderr);
      return 1;
   }
   #ifdef _WIN32
      setmode(STDOUT_FILENO, O_BINARY);
   #endif

   memset(&image, 0, sizeof(image));
   image.version = PNG_IMAGE_VERSION;
   image.format = PNG_FORMAT_GA;
   image.width = IMAGE_WIDTH;
   image.height = IMAGE_HEIGHT;
   pixels = (png_bytep)calloc(PNG_IMAGE_SIZE(image), 1);
   if( pixels == NULL )
   {
      printf("Not enough memory for %d bytes\n", (int)(PNG_IMAGE_SIZE(image)));
      return 1;
   }

   /* Draw tiles. */
   AddWallAdjacentTiles(pixels);
   AddSolidWallTile(pixels);
   AddDebugTiles(pixels);

   /* Write output.  Here we set the flags to optimize for encoding speed
      rather than output size so that we can iterate faster.  This is fine
      since the output of this tool are intermediate files that are used
      only in the build process, and are not the final PNGs that will be
      committed.                                                           */
   image.flags |= PNG_IMAGE_FLAG_FAST;
   if( strcmp(argv[1], "-") == 0 )
   {
      if( !png_image_write_to_stdio(&image, stdout, 0, pixels, 0, NULL) )
      {
         fputs("Error writing to stdout\n", stderr);
         goto fail;
      }
   }
   else
   {
      if( !png_image_write_to_file(&image, argv[1], 0, pixels, 0, NULL) )
      {
         printf("Error writing %s\n", argv[1]);
         goto fail;
      }
   }
   free(pixels);
   return 0;

fail:
   free(pixels);
   return 1;
}
