/* Copy triangular tile regions from one image to another.

   For example, if tile size is 4, the pixels from images 1 and 2 will be
   mixed as follows:

   1111 1111 1111
   1112 1112 1112
   1122 1122 1122
   1222 1222 1222

   1111 1111 1111
   1112 1112 1112
   1122 1122 1122
   1222 1222 1222

   This was an experiment to see what kind of patterns we would get if
   we do the following:

   1. Make two copies of grayscale inputs and call them A and B.
   2. Dither A with Floyd-Steinberg.
   3. Flip B along a diagonal, dither it with Floyd-Steinberg, then
      flip the dithered result back.
   4. Triangle-merge the two dithered images together.

   The thinking was that the top and left edges of each tile were
   predictable because what came before those edges are constant for all
   tiles.  So what happens if we make the bottom and right edges
   predictable as well?  Writing a tool to do step 4 was easier than
   hacking some masking scripts for use with ImageMagick, so here it is.

   Well, the end result is that in addition to the visible tile seams at
   the 4 edges, we also get a diagonal seam.
*/

#include<png.h>
#include<stdio.h>
#include<stdlib.h>
#include<string.h>

int main(int argc, char **argv)
{
   png_image image[2];
   png_bytep pixels[2], r, w;
   int tile_size, i, x, y;

   if( argc != 5 )
   {
      return printf("%s {tile_size} {input1.png} {input2.png} {output.png}\n",
                    *argv);
   }
   tile_size = atoi(argv[1]);
   if( tile_size <= 1 )
   {
      printf("Invalid tile size: %s\n", argv[1]);
      return 1;
   }

   /* Load input. */
   pixels[0] = pixels[1] = NULL;
   for(i = 0; i < 2; i++)
   {
      memset(&image[i], 0, sizeof(image[0]));
      image[i].version = PNG_IMAGE_VERSION;
      if( !png_image_begin_read_from_file(&image[i], argv[i + 2]) )
      {
         printf("Error reading %s\n", argv[i + 2]);
         goto fail;
      }

      image[i].format = PNG_FORMAT_GA;
      pixels[i] = (png_bytep)malloc(PNG_IMAGE_SIZE(image[0]));
      if( pixels[i] == NULL )
      {
         puts("Out of memory");
         goto fail;
      }
      if( !png_image_finish_read(&image[i], NULL, pixels[i], 0, NULL) )
      {
         printf("Error loading %s\n", argv[i + 2]);
         goto fail;
      }
   }

   /* Check dimensions. */
   if( image[0].width != image[1].width || image[0].height != image[1].height )
   {
      printf("Image dimensions mismatched.  %s=(%d,%d), %s=(%d,%d)\n",
             argv[2], (int)image[0].width, (int)image[0].height,
             argv[3], (int)image[1].width, (int)image[1].height);
      goto fail;
   }

   /* Copy selected regions from second image into the first image. */
   r = pixels[1];
   w = pixels[0];
   for(y = 0; y < (int)image[0].height; y++)
   {
      i = y % tile_size;
      for(x = 0; x < (int)image[0].width; x++, r += 2, w += 2)
      {
         if( i + (x % tile_size) >= tile_size )
         {
            *w = *r;
            *(w + 1) = *(r + 1);
         }
      }
   }

   /* Write output.  Here we set the flags to optimize for encoding speed
      rather than output size so that we can iterate faster.  This is fine
      since the output of this tool are intermediate files that are used
      only in the build process, and are not the final PNGs that will be
      committed.                                                           */
   image[0].flags |= PNG_IMAGE_FLAG_FAST;
   if( !png_image_write_to_file(&image[0], argv[4], 0, pixels[0], 0, NULL) )
   {
      printf("Error writing %s\n", argv[4]);
      goto fail;
   }
   free(pixels[0]);
   free(pixels[1]);
   return 0;

fail:
   free(pixels[0]);
   free(pixels[1]);
   return 1;
}
