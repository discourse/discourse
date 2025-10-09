import { encode } from "@jsquash/jpeg";
import resize from "@jsquash/resize";

function resizeWithAspect(
  input_width,
  input_height,
  target_width,
  target_height
) {
  if (!target_width && !target_height) {
    throw Error("Need to specify at least width or height when resizing");
  }

  if (target_width && target_height) {
    return { width: target_width, height: target_height };
  }

  if (!target_width) {
    return {
      width: Math.round((input_width / input_height) * target_height),
      height: target_height,
    };
  }

  return {
    width: target_width,
    height: Math.round((input_height / input_width) * target_width),
  };
}

function logIfDebug(...messages) {
  if (globalThis.debugMode) {
    // eslint-disable-next-line no-console
    console.log(...messages);
  }
}

globalThis.optimize = async function (
  imageData,
  fileName,
  width,
  height,
  settings
) {
  // This variable assignemnt is re-written by webpack at build time.
  // It ensures that the WASM files are loaded from the CDN, just like this JS entrypoint.
  // eslint-disable-next-line no-undef
  __webpack_public_path__ = new URL(
    `${settings.mediaOptimizationBundle}/../..`,
    location.href
  ).toString();

  const mozJpegDefaultOptions = {
    quality: settings.encode_quality,
    baseline: false,
    arithmetic: false,
    progressive: true,
    optimize_coding: true,
    smoothing: 0,
    color_space: 3 /*YCbCr*/,
    quant_table: 3,
    trellis_multipass: false,
    trellis_opt_zero: false,
    trellis_opt_table: false,
    trellis_loops: 1,
    auto_subsample: true,
    chroma_subsample: 2,
    separate_chroma_quality: false,
    chroma_quality: 75,
  };

  const initialSize = imageData.byteLength;
  logIfDebug(`Worker received imageData: ${initialSize}`);

  let maybeResized;

  // resize
  if (width > settings.resize_threshold) {
    try {
      const target_dimensions = resizeWithAspect(
        width,
        height,
        settings.resize_target
      );
      const wrappedImageData = new ImageData(
        new Uint8ClampedArray(imageData),
        width,
        height
      );
      const resizeResult = await resize(wrappedImageData, {
        width: target_dimensions.width,
        height: target_dimensions.height,
        method: "lanczos3",
        premultiply: settings.resize_pre_multiply,
        linearRGB: settings.resize_linear_rgb,
      });
      if (resizeResult.data[3] !== 255) {
        throw "Image corrupted during resize. Falling back to the original for encode";
      }
      maybeResized = resizeResult.data;
      width = target_dimensions.width;
      height = target_dimensions.height;
      logIfDebug(`Worker post resizing file: ${maybeResized.byteLength}`);
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error(`Resize failed`, error);
      maybeResized = imageData;
    }
  } else {
    logIfDebug(`Skipped resize: ${width} < ${settings.resize_threshold}`);
    maybeResized = imageData;
  }

  // mozJPEG re-encode
  const result = await encode(
    new ImageData(maybeResized, width, height),
    mozJpegDefaultOptions
  );

  const finalSize = result.byteLength;
  logIfDebug(`Worker post reencode file: ${finalSize}`);
  logIfDebug(`Reduction: ${(initialSize / finalSize).toFixed(1)}x speedup`);

  if (finalSize < 20000) {
    throw "Final size suspiciously small, discarding optimizations";
  }

  return result;
};
