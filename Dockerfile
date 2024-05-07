FROM ubuntu:latest

# Install dependencies
RUN apt-get update && apt-get install -y build-essential wget git cmake libpng-dev

# Install AFL++
RUN wget https://github.com/AFLplusplus/AFLplusplus/archive/refs/tags/v4.09c.tar.gz \
    && tar -xzvf v4.09c.tar.gz \
    && cd AFLplusplus-* \
    && make \
    && make install

# Write a simple C program that uses libpng to read a PNG file
RUN echo '#include <png.h>\n\
#include <stdlib.h>\n\
\n\
int main(int argc, char *argv[]) {\n\
    if (argc != 2) return 1;\n\
    FILE *fp = fopen(argv[1], "rb");\n\
    if (!fp) return 1;\n\
    png_structp png = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);\n\
    if (!png) return 1;\n\
    png_infop info = png_create_info_struct(png);\n\
    if (!info) return 1;\n\
    if (setjmp(png_jmpbuf(png))) return 1;\n\
    png_init_io(png, fp);\n\
    png_read_info(png, info);\n\
    png_destroy_read_struct(&png, &info, NULL);\n\
    fclose(fp);\n\
    return 0;\n\
}' > pngtest.c

# Compile the program with AFL++'s version of gcc
RUN afl-gcc pngtest.c -o pngtest -lpng

# Create directories for fuzzing input, output and resources
RUN mkdir /fuzzing_input/ /fuzzing_output/ /fuzzing_resources/

# Add some initial input files for fuzzing
COPY sample*.png /fuzzing_input/

# Create a dictionary file for AFL++ inside the Docker container
RUN echo -e "IHDR\nIDAT\nIEND\nPLTE\ntRNS\ncHRM\ngAMA\niCCP\nsBIT\nsRGB\niTXt\ntEXt\nzTXt" > /fuzzing_resources/dictionary

# Define the command that starts the fuzzing process
CMD script -c "stty cols 80 rows 25; timeout 5m afl-fuzz -m 100 -x /fuzzing_resources/dictionary -V 10 -i /fuzzing_input/ -o /fuzzing_output/ -- /pngtest @@"