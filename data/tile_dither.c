/* Convert PNG to black and white.

   Usage:

      ./tile_dither {tile_size} {input.png} {output.png}

   Use "-" for input or output to read/write from stdin/stdout.

   Given a grayscale (8bit) plus alpha (8bit) PNG, output a black and
   white (1bit) plus transparency (1bit) PNG, with Floyd-Steinberg dithering.

   Unlike fs_dither.c, dithering is done at a per-tile basis, where errors
   are reset across individual tiles.  This means the dither pattern will
   remain consistent even if we move the individual tiles around, but
   overall they seem to be worse-looking than applying Floyd-Steinberg to
   the full image all in one shot.  This is because resetting errors across
   tile boundaries makes the dither pattern more regular, and the reason
   why we went with an error diffusion based dithering scheme is to get
   away from the regular patterns of Bayer dithering, so dithering by tiles
   is counter-productive.
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

/* Dither a single tile block. */
static void DitherTile(int tile_size,
                       int image_width,
                       int *row_error[2],
                       png_bytep pixels)
{
   int y0 = 0, y1 = 1, tx, ty, i, o, e;
   png_bytep p;

   memset(row_error[0], 0, (tile_size + 2) * sizeof(int));
   for(ty = 0; ty < tile_size; ty++)
   {
      /* Reset error for next scanline. */
      memset(row_error[y1], 0, (tile_size + 2) * sizeof(int));

      /* Dither a single scanline. */
      p = pixels + ty * image_width * 2;
      for(tx = 0; tx < tile_size; tx++, p += 2)
      {
         /* i = intended grayscale level. */
         i = *p + row_error[y0][tx + 1] / 16;

         /* o = output grayscale level. */
         o = i > 127 ? 255 : 0;
         *p = o;

         /* Propagate error. */
         e = i - o;
         row_error[y0][tx + 2] += e * 7;
         row_error[y1][tx    ] += e * 3;
         row_error[y1][tx + 1] += e * 5;
         row_error[y1][tx + 2] += e;
      }

      y0 ^= 1;
      y1 ^= 1;
   }
}

int main(int argc, char **argv)
{
   png_image image;
   png_bytep pixels, p;
   int tile_size, x, y;
   int *row_error[2];

   if( argc != 4 )
      return printf("%s {tile_size} {input.png} {output.png}\n", *argv);
   tile_size = atoi(argv[1]);
   if( tile_size < 2 )
   {
      printf("Invalid tile size: %s\n", argv[1]);
      return 1;
   }

   if( strcmp(argv[3], "-") == 0 && isatty(STDOUT_FILENO) )
   {
      fputs("Not writing output to stdout because it's a tty\n", stderr);
      return 1;
   }
   #ifdef _WIN32
      setmode(STDIN_FILENO, O_BINARY);
      setmode(STDOUT_FILENO, O_BINARY);
   #endif

   /* Load input. */
   memset(&image, 0, sizeof(image));
   image.version = PNG_IMAGE_VERSION;
   if( strcmp(argv[2], "-") == 0 )
   {
      if( !png_image_begin_read_from_stdio(&image, stdin) )
         return puts("Error reading from stdin");
   }
   else
   {
      if( !png_image_begin_read_from_file(&image, argv[2]) )
         return printf("Error reading %s\n", argv[2]);
   }

   if( (image.width % tile_size) != 0 || (image.height % tile_size) != 0 )
   {
      printf("Image size (%d,%d) is not a multiple of tile size (%d)\n",
             (int)image.width, (int)image.height, tile_size);
      return 1;
   }
   row_error[0] = (int*)malloc((tile_size + 2) * sizeof(int));
   row_error[1] = (int*)malloc((tile_size + 2) * sizeof(int));
   if( row_error[0] == NULL || row_error[1] == NULL )
   {
      printf("Tile size too large: %s\n", argv[1]);
      return 1;
   }

   image.format = PNG_FORMAT_GA;
   pixels = (png_bytep)malloc(PNG_IMAGE_SIZE(image));
   if( pixels == NULL )
      return puts("Out of memory");
   if( !png_image_finish_read(&image, NULL, pixels, 0, NULL) )
   {
      free(pixels);
      return printf("Error loading %s\n", argv[2]);
   }

   /* Dither tiles. */
   for(y = 0; y < (int)image.height; y += tile_size)
   {
      for(x = 0; x < (int)image.width; x += tile_size)
      {
         /* Dither colors and alpha channel independently. */
         DitherTile(tile_size,
                    image.width,
                    row_error,
                    pixels + (y * image.width + x) * 2);
         DitherTile(tile_size,
                    image.width,
                    row_error,
                    pixels + (y * image.width + x) * 2 + 1);
      }
   }

   /* Set color to zero if the corresponding alpha is zero. */
   p = pixels;
   for(y = 0; y < (int)image.height; y++)
   {
      for(x = 0; x < (int)image.width; x++, p += 2)
      {
         if( *(p + 1) == 0 )
            *p = 0;
      }
   }

   /* Write output.  Here we set the flags to optimize for encoding speed
      rather than output size so that we can iterate faster.  This is fine
      since the output of this tool are intermediate files that are used
      only in the build process, and are not the final PNGs that will be
      committed.                                                           */
   image.flags |= PNG_IMAGE_FLAG_FAST;
   x = 0;
   if( strcmp(argv[3], "-") == 0 )
   {
      if( !png_image_write_to_stdio(&image, stdout, 0, pixels, 0, NULL) )
      {
         fputs("Error writing to stdout\n", stderr);
         x = 1;
      }
   }
   else
   {
      if( !png_image_write_to_file(&image, argv[3], 0, pixels, 0, NULL) )
      {
         printf("Error writing %s\n", argv[3]);
         x = 1;
      }
   }
   free(row_error[0]);
   free(row_error[1]);
   free(pixels);
   return x;
}
