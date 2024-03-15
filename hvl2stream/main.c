#include <stdio.h>
#include <unistd.h>
#include <string.h>

#include "hvl_replay.h"

char input_filename[256];
char output_filename[256];

struct hvl_tune *ht = NULL;

int main(int argc, char *argv[])
{
  printf("Hively Bitstream Converter v2 (Based on Tracker CLI player 1.9)\n");
  if( argc < 2 )  {
    printf( "Usage: %s <tune>\n",argv[0]);
    return 0;
  }
  strcpy(input_filename, argv[1]);
  strcat(output_filename, input_filename);
  strcat(output_filename, ".streambits");

  hvl_InitReplayer();

  ht = hvl_LoadTune( input_filename, 44100, 0 );

  if( ht ) {
    for(;;) {
      hvl_DecodeFrame( ht );
    }
  }
  return 0;
}
