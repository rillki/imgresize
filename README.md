# imgresize

A fast command-line image resizing and conversion tool written in D.

## Features

- Resize images by dimensions (e.g., 512x512) or scale factor (e.g., 0.5)
- Convert between formats: PNG, JPEG, BMP, TGA, GIF, QOI, QOIX, DDS, SQZ
- Resizing using using `stb_image_resize2`
- Alpha channel control - keep or remove transparency

## Installation

### Prerequisites
You need to install [D compiler](https://dlang.org/download.html) toolchain to build this project. Ensure you also have `dub` package manager installed on your system. It usually comes with the compiler, but sometimes you may need to install it separately on Linux. 

### Build from Source

```sh
# clone the repository
git clone https://github.com/rillki/imgresize.git
cd imgresize

# build the project
dub build --build=release
```

The executable will be saved in `./bin` folder. 

## Usage

```sh
Usage: imgresize --path <file> --format <fmt> [--size <WxH> --output <file>]
-p         --path Required: Path to input image.
-f       --format Required: Output format (png, jpeg, bmp...).
-s         --size           Target size or ratio (e.g. 256x256 or 0.8). Defaults to original image size.
-o       --output           Output image path. Defaults to 'path'.
-r --remove-alpha           Remove alpha channel. Defaults to 'false'.
-h         --help           This help information.
```

### Examples

#### Resize to specific dimensions:
```bash
imgresize --path photo.jpg --size 800x600 --format png
```

#### Resize relative to one of the dimensions:
```bash
imgresize --path photo.jpg --size 800x --format png
```

#### Scale by factor:
```bash
imgresize --path image.png --size 0.5 --format jpeg
```

#### Convert format without resizing:
```bash
imgresize --path photo.png --format jpeg --output photo.jpg
```

#### Remove transparency:
```bash
imgresize --path logo.png --remove-alpha --output logo-opaque.png
```

#### Quick resize with custom output:
```bash
imgresize -p original.jpg -s 1024x768 -f png -o thumbnail.png
```

## Supported Formats

### Input Formats

```sh
PNG, JPEG, JPEG XL, TGA, GIF, BMP, SQZ, QOI, QOIX, DDS
```

### Output Formats

```sh
PNG, JPEG, TGA, GIF, BMP, SQZ, QOI, QOIX, DDS
```

## Dependencies
For dependencies check out the [`dub.json`](./dub.json) file:
- [gamut](https://github.com/AuburnSounds/gamut) - Image encoding/decoding library
- [stb_image_resize2](https://github.com/nothings/stb) - High-quality image resizing

## LICENSE
MIT.



