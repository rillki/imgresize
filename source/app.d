module app;

import std.conv : to;
import std.math : isNaN;
import std.path : stripExtension;
import std.array : array;
import std.string : toLower, split, isNumeric, indexOf, empty;
import std.algorithm : filter, swap;
import std.getopt : getopt, defaultGetoptPrinter, config;
import gamut : Image, ImageFormat, PixelType, LOAD_RGB, LOAD_ALPHA, LOAD_8BIT, LOAD_NO_PREMUL;
import stb_image_resize2;
import asol;

/// Project name
enum projectLogHeader = "imgresize :: ";

/// Simple logging function + new line. 
auto log(Args...)(Args args) => logPrint!(" ", "\n", projectLogHeader)(args);

/// C printf-like function.
auto logf(Args...)(in string format, Args args) => logPrintf!(projectLogHeader)(format, args);

/// Image dimentions
struct ImageSize
{
    int width;
    int height;
    float scale;
}

/// Convert and resize image
bool convertResizeSave(
    in string inPath,
    in string outPath,
    in ImageSize imageSize,
    in ImageFormat format = ImageFormat.PNG,
    in bool removeAlpha = false)
{
    // load image
    Image img;
    img.loadFromFile(inPath, LOAD_RGB | LOAD_ALPHA | LOAD_8BIT | LOAD_NO_PREMUL);
    if (img.isError)
    {
        log("Failed to load image:", inPath, "-", img.errorMessage);
        return false;
    }

    // calculate target width and height
    int targetWidth, targetHeight;
    immutable ratio = cast(float)img.width / cast(float)img.height;
    if (!imageSize.scale.isNaN)
    {
        targetWidth = (imageSize.scale * img.width).to!int;
        targetHeight = (imageSize.scale * img.height).to!int;
    }
    else if (imageSize.width && imageSize.height)
    {
        if (ratio > 1)
        {
            targetWidth = imageSize.width;
            targetHeight = imageSize.height;
        }
        else
        {
            targetWidth = imageSize.height;
            targetHeight = imageSize.width;
        }
    }
    else if (imageSize.width && !imageSize.height)
    {
        targetWidth = imageSize.width;
        targetHeight = cast(int)(imageSize.width / ratio); 
    }
    else if (!imageSize.width && imageSize.height)
    {
        targetWidth = cast(int)(imageSize.height * ratio);
        targetHeight = imageSize.height; 
    }
    else
    {
        targetWidth = img.width;
        targetHeight = img.height;
    }
    
    // create output image
    Image outimg;
    outimg.create(targetWidth, targetHeight, PixelType.rgba8);
    
    // resize using stb_image_resize2
    void* res = stbir_resize(
        img.scanptr(0), img.width, img.height, img.pitchInBytes,
        outimg.scanptr(0), outimg.width, outimg.height, outimg.pitchInBytes,
        STBIR_RGBA,
        STBIR_TYPE_UINT8_SRGB,
        STBIR_EDGE_CLAMP,
        STBIR_FILTER_DEFAULT
    );

    // check if successful
    if (res is null)
    {
        log("Failed to resize image:", inPath);
        return false;
    }

    // alpha channel settings
    // Handle format-specific conversions
    final switch (format)
    {
        // these formats don't support alpha - convert to RGB
        case ImageFormat.JPEG:
        case ImageFormat.SQZ:
            outimg.convertTo(PixelType.rgb8);
            break;
    
        // these support alpha - keep rgba8 (unless disabled)
        case ImageFormat.PNG:
        case ImageFormat.TGA:
        case ImageFormat.GIF:
        case ImageFormat.QOI:
        case ImageFormat.QOIX:
        case ImageFormat.DDS:
        case ImageFormat.BMP:
            if (removeAlpha)
            {
                outimg.convertTo(PixelType.rgb8);
            }
            break;

        // JPEG XL in Gamut has no alpha support
        case ImageFormat.JXL:
            outimg.convertTo(PixelType.rgb8);
            break;

        case ImageFormat.unknown:
            break;
    }
    
    // save image
    immutable success = outimg.saveToFile(format, outPath);
    if (!success)
    {
        log("Failed to save image:", outPath);
        return false;
    }
    
    return true;
}

/// Map string to ImageFormat
ImageFormat parseFormat(string fmt)
{
    switch (toLower(fmt))
    {
        case "png":  return ImageFormat.PNG;
        case "jpg", "jpeg": return ImageFormat.JPEG;
        case "bmp":  return ImageFormat.BMP;
        case "tga":  return ImageFormat.TGA;
        case "gif":  return ImageFormat.GIF;
        case "qoi":  return ImageFormat.QOI;
        case "qoix": return ImageFormat.QOIX;
        case "dds":  return ImageFormat.DDS;
        case "sqz":  return ImageFormat.SQZ;
        default: return ImageFormat.unknown;
    }
}

/// Parse image size (width, height, scale), e.g.:
/// "256x256" → (256, 256,   0)
/// "256x"    → (256,   0,   0)
/// "x256"    → (  0, 255,   0)
/// "0.8"     → (  0,   0, 0.8)
/// Returns '-1' upon invalid input: → (-1,-1,-1)
ImageSize parseSize(in string sizeStr)
{
    // use default size if not provided
    if (!sizeStr.length) return ImageSize();

    // try to parse a scaling value
    if (sizeStr.isNumeric) return ImageSize(scale: sizeStr.to!float);

    // check if valid dimensions are specified before parsing them
    immutable xPos = sizeStr.indexOf('x');
    if (xPos < 0) return ImageSize(-1, -1, -1);

    // try to parse dimensions
    auto parts = split(sizeStr, "x").filter!(x => !x.empty).array;
    if (parts.length == 2) // WIDTHxHEIGHT
    {
        return ImageSize(parts[0].to!int, parts[1].to!int);
    }
    else if (xPos == 0)    // xHEIGHT
    {
        return ImageSize(0, parts[0].to!int);
    }
    else                   // WIDTHx
    {
        return ImageSize(parts[0].to!int);
    }
}

/// Check if resize needed
bool resizeNeeded(in ImageSize imageSize)
{
    return !imageSize.scale.isNaN || (imageSize.width && imageSize.height);
}

void main(string[] args)
{
    // define args
    string inPath;
    string outPath;
    string sizeStr;
    string formatStr;
    bool removeAlpha = false;
    
    try
    {
        // parse
        auto helpInfo = getopt(
            args,
            config.required, "p|path",   "Path to input image.", &inPath,
            config.required, "f|format", "Output format (png, jpeg, bmp...).", &formatStr,
            "s|size",   "Target or relative size, ratio (e.g. 256x256, 256x, 0.8). Defaults to original image size.", &sizeStr,
            "o|output", "Output image path. Defaults to 'path'.", &outPath,
            "r|remove-alpha", "Remove alpha channel. Defaults to 'false'.", &removeAlpha,
        );

        // help
        if (helpInfo.helpWanted)
        {
            defaultGetoptPrinter(
                "Usage: imgresize --path <file> --format <fmt> [--size <WxH> --output <file>]",
                helpInfo.options
            );
            return;
        }
    }
    catch (Exception e)
    {
        log("Error:", e.msg);
        return;
    }

    // parse image size
    auto imageSize = parseSize(sizeStr);
    if (imageSize.width < 0)
    {
        log("Invalid image dimensions specified:", sizeStr);
        return;
    }
    
    // parse format
    auto format = parseFormat(formatStr);
    if (format == ImageFormat.unknown)
    {
        log("Unsupported format specified:", formatStr);
        return;
    }
        
    // ask for user confirmation if imageSize.scale values are suspiciously small or big
    if (!imageSize.scale.isNaN && (imageSize.scale < 0.1 || imageSize.scale > 5))
    {
        logf("You are asking to resize your image by x%s times.\n", imageSize.scale);
        if (!askYesNo("Are you sure?", defaultYes: false))
        {
            log("Cancel operation.");
            return;
        }
    }
    
    // determine output filename
    if (!outPath)
    {
        immutable base = stripExtension(inPath);
        outPath = base ~ "." ~ formatStr;
    }

    // log
    if (resizeNeeded(imageSize))
    {
        log("Resizing image:", inPath);
        logf("Specified size: %s%s\n", isNumeric(sizeStr) ? "x" : "", sizeStr);
    }
    else
    {
        log("Converting image:", inPath);
        log("Specified format:", formatStr);
    }
    log("Remove alpha channel:", removeAlpha);
    
    // convert
    immutable success = convertResizeSave(inPath, outPath, imageSize, format, removeAlpha);
    if (!success) return;
    
    // log
    if (resizeNeeded(imageSize)) log("Image resized successfully!");
    else log("Image converted successfully!");
    log("Image saved to:", outPath);
}



