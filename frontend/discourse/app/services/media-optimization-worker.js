import Service, { service } from "@ember/service";
import { Promise } from "rsvp";
import workerUrl from "virtual:dynamic-chunk-url:discourse/workers/media-optimization/entrypoint";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import { fileToImageData } from "discourse/lib/media-optimization-utils";

const CONVERT_FORMAT_REGEX = /(\.|\/)(jxl|hei[cf])$/i;
const ANIMATED_GIF_REGEX = /(\.|\/)(gif)$/i;
const OPTIMIZABLE_REGEX = /(\.|\/)(jpe?g|png)$/i;

/**
 * Optimizes composer image uploads in a worker. The flow:
 *
 * 1. optimizeImage called
 * 2. worker started if one isn't already running, message handlers registered
 * 3. "compress"/"convert" message posted to the worker
 * 4. worker posts back the optimized file (or an error), resolving the upload
 *
 * The worker is a module worker bundled with its codecs, so it is ready as soon
 * as it is created (posted messages queue until its module evaluates). A worker
 * that fails to boot surfaces via onerror, and in-flight uploads continue
 * unoptimized.
 */
@disableImplicitInjections
export default class MediaOptimizationWorkerService extends Service {
  @service appEvents;
  @service siteSettings;
  @service capabilities;

  worker = null;
  currentComposerUploadData = null;
  promiseResolvers = null;
  workerDoneCount = 0;
  workerPendingCount = 0;

  async optimizeImage(data, opts = {}) {
    this.promiseResolvers = this.promiseResolvers || {};
    this.stopWorkerOnError = opts.hasOwnProperty("stopWorkerOnError")
      ? opts.stopWorkerOnError
      : true;

    let file = data;
    const typeOrName = file.type || file.name;

    const isConvertFormat = CONVERT_FORMAT_REGEX.test(typeOrName);
    const isAnimatedGif = ANIMATED_GIF_REGEX.test(typeOrName);
    const isOptimizable = OPTIMIZABLE_REGEX.test(typeOrName);
    const wasmDecodeOptimizable =
      isOptimizable &&
      this.siteSettings.composer_media_optimization_image_wasm_decode_enabled;

    if (!isConvertFormat && !isAnimatedGif && !isOptimizable) {
      return Promise.resolve();
    }

    // JXL/HEIC/GIF conversion is gated behind a separate site setting
    if (
      (isConvertFormat || isAnimatedGif) &&
      !this.siteSettings.composer_media_optimization_image_convert_enabled
    ) {
      return Promise.resolve();
    }

    if (isOptimizable) {
      if (
        file.size <
        this.siteSettings
          .composer_media_optimization_image_bytes_optimization_threshold
      ) {
        this.logIfDebug(
          `The file ${file.name} was less than the image optimization bytes threshold (${this.siteSettings.composer_media_optimization_image_bytes_optimization_threshold} bytes), skipping`,
          file
        );
        return Promise.resolve();
      }
    } else if (isAnimatedGif) {
      if (
        file.size <
        this.siteSettings.composer_media_optimization_gif_conversion_threshold
      ) {
        this.logIfDebug(
          `The GIF ${file.name} was less than the GIF conversion threshold (${this.siteSettings.composer_media_optimization_gif_conversion_threshold} bytes), skipping`,
          file
        );
        return Promise.resolve();
      }
    }

    this.ensureAvailableWorker();
    if (!this.worker) {
      return Promise.resolve();
    }

    return new Promise(async (resolve) => {
      this.logIfDebug(`Transforming ${file.name}`);

      this.currentComposerUploadData = data;
      this.promiseResolvers[file.id] = resolve;

      const settings = {
        resize_threshold:
          this.siteSettings
            .composer_media_optimization_image_resize_dimensions_threshold,
        resize_target:
          this.siteSettings
            .composer_media_optimization_image_resize_width_target,
        resize_pre_multiply:
          this.siteSettings
            .composer_media_optimization_image_resize_pre_multiply,
        resize_linear_rgb:
          this.siteSettings.composer_media_optimization_image_resize_linear_rgb,
        encode_quality:
          this.siteSettings.composer_media_optimization_image_encode_quality !==
          0
            ? this.siteSettings.composer_media_optimization_image_encode_quality
            : this.siteSettings.image_quality,
        debug_mode: this.siteSettings.composer_media_optimization_debug_mode,
      };

      if (isConvertFormat || wasmDecodeOptimizable) {
        let arrayBuffer;
        try {
          arrayBuffer = await file.data.arrayBuffer();
        } catch (error) {
          this.logIfDebug(error);
          return resolve();
        }

        this.worker.postMessage(
          {
            type: "convert",
            fileId: file.id,
            file: arrayBuffer,
            fileName: file.name,
            fileType: file.type || file.data.type || file.name,
            originalFileSize: file.size,
            settings,
          },
          [arrayBuffer]
        );
      } else if (isAnimatedGif) {
        let arrayBuffer;
        try {
          arrayBuffer = await file.data.arrayBuffer();
        } catch (error) {
          this.logIfDebug(error);
          return resolve();
        }

        this.worker.postMessage(
          {
            type: "convertAnimated",
            fileId: file.id,
            file: arrayBuffer,
            fileName: file.name,
            originalFileSize: file.size,
            settings,
          },
          [arrayBuffer]
        );
      } else {
        let imageData;
        try {
          imageData = await fileToImageData(file.data, this.capabilities.isIOS);
        } catch (error) {
          this.logIfDebug(error);
          return resolve();
        }

        this.worker.postMessage(
          {
            type: "compress",
            fileId: file.id,
            file: imageData.data.buffer,
            fileName: file.name,
            width: imageData.width,
            height: imageData.height,
            originalFileSize: file.size,
            settings,
          },
          [imageData.data.buffer]
        );
      }

      this.workerPendingCount++;
    });
  }

  ensureAvailableWorker() {
    if (!this.worker) {
      this.startWorker();
    }
  }

  startWorker() {
    this.logIfDebug("Starting media-optimization-worker");
    // Module workers queue posted messages until their module has evaluated, so
    // the worker is usable immediately; a failure to boot surfaces via onerror.
    try {
      const blobUrl = URL.createObjectURL(
        new Blob([`import ${JSON.stringify(workerUrl)};`], {
          type: "text/javascript",
        })
      );
      try {
        this.worker = new Worker(blobUrl, { type: "module" });
      } finally {
        URL.revokeObjectURL(blobUrl);
      }
    } catch (err) {
      this.logIfDebug("Error starting media-optimization-worker", err);
      return;
    }
    this.registerMessageHandler();
    this.worker.onerror = (err) => this.handleWorkerError(err);
    this.appEvents.on("composer:closed", this, "stopWorker");
  }

  handleWorkerError(err) {
    this.logIfDebug("media-optimization-worker error", err);
    this.stopWorker();
    // Resolve any in-flight optimizations so their uploads continue unoptimized.
    Object.values(this.promiseResolvers ?? {}).forEach((resolve) =>
      resolve?.()
    );
  }

  stopWorker() {
    if (this.worker) {
      this.logIfDebug("Stopping media-optimization-worker...");
      this.worker.terminate();
      this.worker = null;
      this.workerDoneCount = 0;
    }
    this.workerPendingCount = 0;
  }

  _renameForOutputType(fileName, outputType) {
    const baseName = fileName.replace(/\.[^.]+$/, "");
    switch (outputType) {
      case "image/jpeg":
        return baseName + ".jpg";
      case "image/png":
        return baseName + ".png";
      case "image/webp":
        return baseName + ".webp";
      default:
        return fileName;
    }
  }

  registerMessageHandler() {
    this.worker.onmessage = (workerMessage) => {
      switch (workerMessage.data.type) {
        case "file":
          const outputType = workerMessage.data.outputType || "image/jpeg";
          const outputFileName = this._renameForOutputType(
            workerMessage.data.fileName,
            outputType
          );
          const optimizedFile = new File(
            [workerMessage.data.file],
            outputFileName,
            {
              type: outputType,
            }
          );
          this.logIfDebug(
            `Finished optimization of ${optimizedFile.name}, new size is ${optimizedFile.size} bytes`
          );

          this.promiseResolvers[workerMessage.data.fileId](optimizedFile);

          this.workerDoneCount++;
          this.workerPendingCount--;
          if (this.workerDoneCount > 4 && this.workerPendingCount === 0) {
            this.logIfDebug("Terminating worker to release memory in WASM");
            this.stopWorker();
          }

          break;
        case "error":
          this.logIfDebug(
            `Handling error message from image optimization for ${workerMessage.data.fileName}`
          );

          if (this.stopWorkerOnError) {
            this.stopWorker();
          }

          this.promiseResolvers[workerMessage.data.fileId]();
          this.workerPendingCount--;
          break;
        case "skipped":
          this.logIfDebug(
            `Conversion skipped for ${workerMessage.data.fileName} (output not smaller than original)`
          );

          this.promiseResolvers[workerMessage.data.fileId]();
          this.workerDoneCount++;
          this.workerPendingCount--;
          break;
        default:
          this.logIfDebug(`Sorry, we are out of ${workerMessage}`);
      }
    };
  }

  logIfDebug(...messages) {
    if (this.siteSettings.composer_media_optimization_debug_mode) {
      // eslint-disable-next-line no-console
      console.log("[media-optimization-worker]", ...messages);
    }
  }
}
