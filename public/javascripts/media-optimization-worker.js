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

function logIfDebug(message) {
  if (DedicatedWorkerGlobalScope.debugMode) {
    // eslint-disable-next-line no-console
    console.log(message);
  }
}

async function optimize(imageData, fileName, width, height, settings) {
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
      const resizeResult = self.codecs.resize(
        new Uint8ClampedArray(imageData),
        width, //in
        height, //in
        target_dimensions.width, //out
        target_dimensions.height, //out
        3, // 3 is lanczos
        settings.resize_pre_multiply,
        settings.resize_linear_rgb
      );
      if (resizeResult[3] !== 255) {
        throw "Image corrupted during resize. Falling back to the original for encode";
      }
      maybeResized = new ImageData(
        resizeResult,
        target_dimensions.width,
        target_dimensions.height
      ).data;
      width = target_dimensions.width;
      height = target_dimensions.height;
      logIfDebug(`Worker post resizing file: ${maybeResized.byteLength}`);
    } catch (error) {
      console.error(`Resize failed: ${error}`);
      maybeResized = imageData;
    }
  } else {
    logIfDebug(`Skipped resize: ${width} < ${settings.resize_threshold}`);
    maybeResized = imageData;
  }

  // mozJPEG re-encode
  const result = self.codecs.mozjpeg_enc.encode(
    maybeResized,
    width,
    height,
    mozJpegDefaultOptions
  );

  const finalSize = result.byteLength;
  logIfDebug(`Worker post reencode file: ${finalSize}`);
  logIfDebug(`Reduction: ${(initialSize / finalSize).toFixed(1)}x speedup`);

  if (finalSize < 20000) {
    throw "Final size suspciously small, discarding optimizations";
  }

  let transferrable = Uint8Array.from(result).buffer; // decoded was allocated inside WASM so it **cannot** be transfered to another context, need to copy by value

  return transferrable;
}

onmessage = async function (e) {
  switch (e.data.type) {
    case "compress":
      try {
        DedicatedWorkerGlobalScope.debugMode = e.data.settings.debug_mode;
        let optimized = await optimize(
          e.data.file,
          e.data.fileName,
          e.data.width,
          e.data.height,
          e.data.settings
        );
        postMessage(
          {
            type: "file",
            file: optimized,
            fileName: e.data.fileName,
            fileId: e.data.fileId,
          },
          [optimized]
        );
      } catch (error) {
        console.error(error);
        postMessage({
          type: "error",
          file: e.data.file,
          fileName: e.data.fileName,
          fileId: e.data.fileId,
        });
      }
      break;
    case "install":
      try {
        await loadLibs(e.data.settings);
        postMessage({ type: "installed" });
      } catch (error) {
        postMessage({ type: "installFailed", errorMessage: error.message });
      }
      break;
    default:
      logIfDebug(`Sorry, we are out of ${e}.`);
  }
};

async function loadLibs(settings) {
  if (self.codecs) return;

  importScripts(settings.mozjpeg_script);
  importScripts(settings.resize_script);

  let encoderModuleOverrides = {
    locateFile: function (path, prefix) {
      // if it's a mem init file, use a custom dir
      if (path.endsWith(".wasm")) return settings.mozjpeg_wasm;
      // otherwise, use the default, the prefix (JS file's dir) + the path
      return prefix + path;
    },
    onRuntimeInitialized: function () {
      return this;
    },
  };
  const mozjpeg_enc_module = await mozjpeg_enc(encoderModuleOverrides);

  const { resize } = wasm_bindgen;
  await wasm_bindgen(settings.resize_wasm);

  self.codecs = { mozjpeg_enc: mozjpeg_enc_module, resize: resize };
}
