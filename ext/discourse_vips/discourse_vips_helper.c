#include <glib.h>
#include <limits.h>
#include <math.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <vips/vips.h>

typedef struct {
  const char *key;
  const char *value;
} option_t;

typedef struct {
  option_t items[32];
  int count;
} options_t;

#define MAX_DIRECT_RESIZE_FACTOR 256

static const char *option(options_t *options, const char *key) {
  for (int index = 0; index < options->count; index++) {
    if (strcmp(options->items[index].key, key) == 0) {
      return options->items[index].value;
    }
  }
  return NULL;
}

static const char *required_option(options_t *options, const char *key) {
  const char *value = option(options, key);
  if (!value || value[0] == '\0') {
    fprintf(stderr, "missing required option --%s\n", key);
    exit(2);
  }
  return value;
}

static int integer_option(options_t *options, const char *key, int fallback) {
  const char *value = option(options, key);
  if (!value) {
    return fallback;
  }

  char *end = NULL;
  long parsed = strtol(value, &end, 10);
  if (!end || *end != '\0' || parsed < INT_MIN || parsed > INT_MAX) {
    fprintf(stderr, "invalid integer for --%s\n", key);
    exit(2);
  }
  return (int)parsed;
}

static void parse_options(int argc, char **argv, options_t *options) {
  options->count = 0;
  for (int index = 2; index < argc; index++) {
    if (strncmp(argv[index], "--", 2) != 0) {
      fprintf(stderr, "unexpected argument: %s\n", argv[index]);
      exit(2);
    }
    if (index + 1 >= argc) {
      fprintf(stderr, "missing value for %s\n", argv[index]);
      exit(2);
    }
    if (options->count >= 32) {
      fprintf(stderr, "too many options\n");
      exit(2);
    }
    options->items[options->count].key = argv[index] + 2;
    options->items[options->count].value = argv[++index];
    options->count++;
  }
}

static void report_error(const char *message) {
  fprintf(stderr, "%s\n", message);
}

static void report_vips_error(void) {
  const char *message = vips_error_buffer();
  report_error(message && message[0] ? message : "libvips error");
}

static void set_loader_block(const char *name, gboolean blocked) {
  vips_operation_block_set(name, blocked);
}

static void block_loaders(void) {
  vips_block_untrusted_set(TRUE);
  set_loader_block("VipsForeignLoad", TRUE);
  set_loader_block("VipsForeignLoadMagick", TRUE);
  set_loader_block("VipsForeignLoadMagick6", TRUE);
  set_loader_block("VipsForeignLoadMagick7", TRUE);
}

static void allow_loader_family(const char *base, const char *file) {
  set_loader_block(base, FALSE);
  set_loader_block(file, FALSE);
}

static void allow_dominant_color_loaders(void) {
  allow_loader_family("VipsForeignLoadJpeg", "VipsForeignLoadJpegFile");
  allow_loader_family("VipsForeignLoadPng", "VipsForeignLoadPngFile");
  allow_loader_family("VipsForeignLoadNsgif", "VipsForeignLoadNsgifFile");
  allow_loader_family("VipsForeignLoadWebp", "VipsForeignLoadWebpFile");
  allow_loader_family("VipsForeignLoadHeif", "VipsForeignLoadHeifFile");
  allow_loader_family("VipsForeignLoadJxl", "VipsForeignLoadJxlFile");
}

static int initialize_vips(const char *program) {
  if (VIPS_INIT(program)) {
    return -1;
  }
  if (vips_version(0) < 8 || (vips_version(0) == 8 && vips_version(1) < 13)) {
    vips_error("discourse-vips", "libvips >= 8.13 is required (found %d.%d)",
               vips_version(0), vips_version(1));
    return -1;
  }
  block_loaders();
  vips_concurrency_set(1);
  vips_cache_set_max(0);
  vips_cache_set_max_mem(0);
  vips_cache_set_max_files(0);
  return 0;
}

static int save_png(VipsImage *image, const char *output, int compression) {
  return vips_pngsave(image, output, "compression", compression, NULL);
}

static unsigned char quantize_sample(double value, double sample_max) {
  value = fmin(sample_max, fmax(0.0, value));
  return (unsigned char)floor(value * 255.0 / sample_max + 0.5);
}

static int command_version(options_t *options) {
  (void)options;
  printf("%d.%d.%d\n", vips_version(0), vips_version(1), vips_version(2));
  return 0;
}

static int command_letter_avatar(options_t *options) {
  const char *output = required_option(options, "output");
  const char *markup = option(options, "markup");
  const char *font = required_option(options, "font");
  const char *fontfile = option(options, "fontfile");
  int size = integer_option(options, "size", 0);
  int red = integer_option(options, "red", -1);
  int green = integer_option(options, "green", -1);
  int blue = integer_option(options, "blue", -1);
  markup = markup ? markup : "";
  fontfile = fontfile ? fontfile : "";

  if (size < 1 || size > 4096) {
    report_error("size must be 1..4096");
    return 1;
  }
  if (red < 0 || red > 255 || green < 0 || green > 255 || blue < 0 ||
      blue > 255) {
    report_error("background channels must be 0..255");
    return 1;
  }
  if (vips_type_find("VipsOperation", "text") == 0) {
    report_error("libvips has no Pango text renderer");
    return 1;
  }

  VipsImage *text = NULL;
  VipsImage *canvas = NULL;
  VipsImage *flattened = NULL;
  double canvas_background_values[4] = {red, green, blue, 255};
  double flattened_background_values[3] = {red, green, blue};
  VipsArrayDouble *canvas_background =
      vips_array_double_new(canvas_background_values, 4);
  VipsArrayDouble *flattened_background =
      vips_array_double_new(flattened_background_values, 3);

  int result = fontfile[0] == '\0'
                   ? vips_text(&text, markup, "font", font, "dpi", 72, "rgba",
                               TRUE, NULL)
                   : vips_text(&text, markup, "font", font, "dpi", 72,
                               "fontfile", fontfile, "rgba", TRUE, NULL);
  if (result == 0) {
    result = vips_gravity(text, &canvas, VIPS_COMPASS_DIRECTION_CENTRE, size,
                          size, "extend", VIPS_EXTEND_BACKGROUND, "background",
                          canvas_background, NULL);
  }
  if (result == 0) {
    result = vips_flatten(canvas, &flattened, "background",
                          flattened_background, NULL);
  }
  if (result == 0) {
    result = save_png(flattened, output, 6);
  }
  if (result != 0) {
    report_vips_error();
    VIPS_UNREF(text);
    VIPS_UNREF(canvas);
    VIPS_UNREF(flattened);
    VipsArrayDouble_unref(canvas_background);
    VipsArrayDouble_unref(flattened_background);
    return 1;
  }

  VIPS_UNREF(text);
  VIPS_UNREF(canvas);
  VIPS_UNREF(flattened);
  VipsArrayDouble_unref(canvas_background);
  VipsArrayDouble_unref(flattened_background);
  return 0;
}

static int command_resize_letter_avatar(options_t *options) {
  const char *input = required_option(options, "input");
  const char *output = required_option(options, "output");
  const char *profile = required_option(options, "profile");
  int size = integer_option(options, "size", 0);
  if (size < 1 || size > 4096) {
    report_error("size must be 1..4096");
    return 1;
  }

  allow_loader_family("VipsForeignLoadPng", "VipsForeignLoadPngFile");
  VipsImage *thumbnail = NULL;
  VipsImage *sharpened = NULL;
  int result = vips_thumbnail(input, &thumbnail, size, "height", size, "size",
                              VIPS_SIZE_BOTH, "crop", VIPS_INTERESTING_CENTRE,
                              "output_profile", profile, NULL);
  if (result == 0) {
    result = vips_sharpen(thumbnail, &sharpened, "sigma", 0.5, "m1", 0.7, NULL);
  }
  if (result == 0) {
    result = vips_pngsave(sharpened, output, "palette", TRUE, "Q", 100,
                          "compression", 6, "strip", TRUE, NULL);
  }
  if (result != 0) {
    report_vips_error();
  }
  VIPS_UNREF(thumbnail);
  VIPS_UNREF(sharpened);
  return result == 0 ? 0 : 1;
}

static int command_dominant_color(options_t *options) {
  const char *input = required_option(options, "input");
  VipsImage *image = NULL;
  VipsImage *double_image = NULL;
  VipsImage *premultiplied = NULL;
  VipsImage *bordered = NULL;
  VipsImage *resized = NULL;
  VipsImage *resized_pixel = NULL;
  VipsImage *unpremultiplied = NULL;
  double *components = NULL;
  int result = 1;

  allow_dominant_color_loaders();
  const char *loader = vips_foreign_find_load(input);
  if (!loader) {
    report_error("unsupported input format");
    goto cleanup;
  }

  if (strcmp(loader, "VipsForeignLoadHeifFile") == 0) {
    image = vips_image_new_from_file(input, "access", VIPS_ACCESS_SEQUENTIAL,
                                     "fail_on", VIPS_FAIL_ON_NONE, "thumbnail",
                                     FALSE, NULL);
  } else {
    image = vips_image_new_from_file(input, "access", VIPS_ACCESS_SEQUENTIAL,
                                     "fail_on", VIPS_FAIL_ON_NONE, NULL);
  }
  if (!image) {
    report_vips_error();
    goto cleanup;
  }

  int width = vips_image_get_width(image);
  int height = vips_image_get_height(image);
  if (width < 1 || height < 1 || width > INT_MAX / 7 || height > INT_MAX / 7) {
    report_error("unsupported image dimensions");
    goto cleanup;
  }

  VipsBandFormat format = vips_image_get_format(image);
  int bands = vips_image_get_bands(image);
  if ((format != VIPS_FORMAT_UCHAR && format != VIPS_FORMAT_USHORT) ||
      bands < 1 || bands > 4) {
    report_error("unsupported pixel format");
    goto cleanup;
  }
  double sample_max = format == VIPS_FORMAT_USHORT ? 65535.0 : 255.0;

  result = vips_cast(image, &double_image, VIPS_FORMAT_DOUBLE, NULL);
  bool has_alpha = vips_image_hasalpha(image);
  VipsImage *resize_input = double_image;
  if (result == 0 && has_alpha) {
    result = vips_premultiply(double_image, &premultiplied, "max_alpha",
                              sample_max, NULL);
    resize_input = premultiplied;
  }
  bool direct_resize =
      width <= MAX_DIRECT_RESIZE_FACTOR && height <= MAX_DIRECT_RESIZE_FACTOR;
  if (result == 0 && direct_resize && has_alpha) {
    result =
        vips_embed(resize_input, &bordered, width * 3, height * 3, width * 7,
                   height * 7, "extend", VIPS_EXTEND_BLACK, NULL);
    if (result == 0) {
      result =
          vips_resize(bordered, &resized, 1.0 / width, "vscale", 1.0 / height,
                      "kernel", VIPS_KERNEL_LANCZOS3, "gap", 0.0, NULL);
    }
    if (result == 0) {
      result = vips_extract_area(resized, &resized_pixel, 3, 3, 1, 1, NULL);
    }
  } else if (result == 0) {
    result = vips_resize(resize_input, &resized_pixel, 1.0 / width, "vscale",
                         1.0 / height, "kernel", VIPS_KERNEL_LANCZOS3, "gap",
                         direct_resize ? 0.0 : 2.0, NULL);
  }
  if (result == 0 && has_alpha) {
    result = vips_unpremultiply(resized_pixel, &unpremultiplied, "max_alpha",
                                sample_max, NULL);
  }
  VipsImage *pixel = has_alpha ? unpremultiplied : resized_pixel;
  if (result != 0) {
    report_vips_error();
    goto cleanup;
  }
  if (vips_image_get_width(pixel) != 1 || vips_image_get_height(pixel) != 1) {
    report_error("dominant color did not produce one pixel");
    goto cleanup;
  }

  int component_count = 0;
  if (vips_getpoint(pixel, &components, &component_count, 0, 0, NULL) != 0 ||
      !components || component_count != bands) {
    report_error("unable to read dominant color pixel");
    goto cleanup;
  }

  unsigned char red = quantize_sample(components[0], sample_max);
  unsigned char green =
      quantize_sample(bands < 3 ? components[0] : components[1], sample_max);
  unsigned char blue =
      quantize_sample(bands < 3 ? components[0] : components[2], sample_max);
  char color[7];
  snprintf(color, sizeof(color), "%02X%02X%02X", red, green, blue);
  puts(color);
  result = 0;

cleanup:
  g_free(components);
  VIPS_UNREF(image);
  VIPS_UNREF(double_image);
  VIPS_UNREF(premultiplied);
  VIPS_UNREF(bordered);
  VIPS_UNREF(resized);
  VIPS_UNREF(resized_pixel);
  VIPS_UNREF(unpremultiplied);
  return result;
}

static int command_topic_og(options_t *options) {
  const char *input = required_option(options, "input");
  const char *output = required_option(options, "output");
  allow_loader_family("VipsForeignLoadSvg", "VipsForeignLoadSvgFile");

  VipsImage *svg = NULL;
  VipsImage *flattened = NULL;
  int result = vips_svgload(input, &svg, NULL);
  if (result == 0) {
    result = vips_flatten(svg, &flattened, NULL);
  }
  if (result == 0) {
    result = save_png(flattened, output, 9);
  }
  if (result != 0) {
    report_vips_error();
    VIPS_UNREF(svg);
    VIPS_UNREF(flattened);
    return 1;
  }

  VIPS_UNREF(svg);
  VIPS_UNREF(flattened);
  return 0;
}

int main(int argc, char **argv) {
  if (argc < 2) {
    fprintf(stderr, "usage: %s COMMAND [OPTIONS]\n", argv[0]);
    return 2;
  }

  options_t options;
  parse_options(argc, argv, &options);
  if (initialize_vips(argv[0]) != 0) {
    report_vips_error();
    return 1;
  }

  const char *command = argv[1];
  int result;
  if (strcmp(command, "version") == 0) {
    result = command_version(&options);
  } else if (strcmp(command, "letter-avatar") == 0) {
    result = command_letter_avatar(&options);
  } else if (strcmp(command, "resize-letter-avatar") == 0) {
    result = command_resize_letter_avatar(&options);
  } else if (strcmp(command, "dominant-color") == 0) {
    result = command_dominant_color(&options);
  } else if (strcmp(command, "topic-og") == 0) {
    result = command_topic_og(&options);
  } else {
    report_error("unsupported helper command");
    result = 2;
  }

  vips_shutdown();
  return result;
}
