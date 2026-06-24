import { decodeAnimated as decodeGifAnimated } from "@discourse/gif";
import { decode as decodeHeic } from "@discourse/heic";
import { decode as decodeJpeg, encode as encodeJpeg } from "@discourse/jpeg";
import { decode as decodeJxl } from "@discourse/jxl";
import { decode as decodePng } from "@discourse/png";
import resize from "@discourse/resize";
import {
  encode as encodeWebp,
  encodeAnimated as encodeWebpAnimated,
} from "@discourse/webp";

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
    console.log("[media-optimization-worker]", ...messages);
  }
}

function buildMozJpegOptions(settings) {
  return {
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
}

function hasTransparency(imageData) {
  for (let i = 3; i < imageData.data.length; i += 4) {
    if (imageData.data[i] < 255) {
      return true;
    }
  }
  return false;
}

async function maybeResize(imageData, width, height, settings) {
  if (width > settings.resize_threshold) {
    try {
      const targetDimensions = resizeWithAspect(
        width,
        height,
        settings.resize_target
      );
      const resizeResult = await resize(imageData, {
        width: targetDimensions.width,
        height: targetDimensions.height,
        method: "lanczos3",
        premultiply: settings.resize_pre_multiply,
        linearRGB: settings.resize_linear_rgb,
      });
      if (resizeResult.data[3] !== 255) {
        throw "Image corrupted during resize. Falling back to the original for encode";
      }
      logIfDebug(
        `Post-resizing size is ${resizeResult.data.byteLength} bytes (raw uncompressed pixels at ${targetDimensions.width}x${targetDimensions.height})`
      );
      return resizeResult;
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error("Resize failed", error);
      return imageData;
    }
  } else {
    logIfDebug(`Skipped resize, ${width} < ${settings.resize_threshold}`);
    return imageData;
  }
}

export async function optimize(
  imageData,
  fileName,
  width,
  height,
  originalFileSize,
  settings
) {
  const mozJpegOptions = buildMozJpegOptions(settings);

  const initialSize = imageData.byteLength;
  logIfDebug(
    `Received imageData ${initialSize} bytes (raw uncompressed pixels) from original file size of ${originalFileSize} bytes (compressed) for ${fileName}`
  );

  const wrappedImageData = new ImageData(
    new Uint8ClampedArray(imageData),
    width,
    height
  );
  const resized = await maybeResize(wrappedImageData, width, height, settings);
  const finalWidth = resized.width;
  const finalHeight = resized.height;

  const result = await encodeJpeg(
    resized instanceof ImageData
      ? resized
      : new ImageData(
          new Uint8ClampedArray(resized.data),
          finalWidth,
          finalHeight
        ),
    mozJpegOptions
  );

  const finalSize = result.byteLength;
  logIfDebug(
    `Post-reencode size for ${fileName} is ${finalSize} bytes (compressed JPEG), original was ${originalFileSize} bytes`
  );
  const compressionFromOriginal = (originalFileSize / finalSize).toFixed(1);
  const compressionFromRaw = (initialSize / finalSize).toFixed(1);
  logIfDebug(
    `Compressed ${compressionFromOriginal}x vs original file, ${compressionFromRaw}x vs raw pixels for ${fileName}`
  );

  if (finalSize < 20000) {
    throw "Final size suspiciously small, discarding optimizations";
  }

  return result;
}

export async function convert(
  fileBuffer,
  fileName,
  fileType,
  originalFileSize,
  settings
) {
  logIfDebug(`Converting ${fileName} (${fileType}, ${originalFileSize} bytes)`);

  let imageData;
  if (/jxl$/i.test(fileType)) {
    imageData = await decodeJxl(fileBuffer);
  } else if (/hei[cf]$/i.test(fileType)) {
    imageData = await decodeHeic(fileBuffer);
  } else if (/jpe?g$/i.test(fileType)) {
    imageData = await decodeJpeg(fileBuffer, { preserveOrientation: true });
  } else if (/png$/i.test(fileType)) {
    imageData = await decodePng(fileBuffer);
  } else {
    throw `Unsupported file type for conversion: ${fileType}`;
  }

  logIfDebug(
    `Decoded ${fileName} to ${imageData.width}x${imageData.height} ImageData`
  );

  const transparent = hasTransparency(imageData);

  const resized = await maybeResize(
    imageData,
    imageData.width,
    imageData.height,
    settings
  );

  if (transparent) {
    logIfDebug(
      `Image ${fileName} has transparency, encoding as WEBP instead of JPEG`
    );
    const result = await encodeWebp(resized, {
      quality: settings.encode_quality,
    });
    const finalSize = result.byteLength;
    logIfDebug(
      `Converted ${fileName} from ${originalFileSize} bytes to ${finalSize} bytes WEBP`
    );
    return { data: result, outputType: "image/webp" };
  }

  const result = await encodeJpeg(resized, buildMozJpegOptions(settings));

  const finalSize = result.byteLength;
  logIfDebug(
    `Converted ${fileName} from ${originalFileSize} bytes to ${finalSize} bytes JPEG (${(originalFileSize / finalSize).toFixed(1)}x compression)`
  );

  if (finalSize < 20000) {
    throw "Final size suspiciously small, discarding conversion";
  }

  return { data: result, outputType: "image/jpeg" };
}

export async function convertAnimated(
  fileBuffer,
  fileName,
  originalFileSize,
  settings
) {
  logIfDebug(
    `Converting animated ${fileName} (${originalFileSize} bytes) to animated WEBP`
  );

  const frames = await decodeGifAnimated(fileBuffer);
  logIfDebug(`Decoded ${frames.length} frames from ${fileName}`);

  const result = await encodeWebpAnimated(frames, {
    quality: settings.encode_quality,
  });

  const finalSize = result.byteLength;
  logIfDebug(
    `Converted animated ${fileName} from ${originalFileSize} bytes to ${finalSize} bytes WEBP (${(originalFileSize / finalSize).toFixed(1)}x compression)`
  );

  if (finalSize >= originalFileSize) {
    logIfDebug(
      `Animated WEBP (${finalSize} bytes) is not smaller than original GIF (${originalFileSize} bytes), skipping conversion`
    );
    return null;
  }

  return { data: result, outputType: "image/webp" };
}
