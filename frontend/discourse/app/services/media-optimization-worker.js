import Service, { service } from "@ember/service";
import { Promise } from "rsvp";
import { getAbsoluteURL } from "discourse/lib/get-url";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import { fileToImageData } from "discourse/lib/media-optimization-utils";

const WORKER_INSTALL_TIMEOUT_MS = 3000;

/**
 * This worker follows a particular promise/callback flow to ensure
 * that the media-optimization-worker is installed and has its libraries
 * loaded before optimizations can happen. The flow:
 *
 * 1. optimizeImage called
 * 2. worker initialized and started
 * 3. message handlers for worker registered
 * 4. "install" message posted to worker
 * 5. "installed" message received from worker
 * 6. optimizeImage continues, posting "compress" message to worker
 *
 * When the worker is being installed, all other calls to optimizeImage
 * will wait for the "installed" message to be handled before continuing
 * with any image optimization work.
 */
@disableImplicitInjections
export default class MediaOptimizationWorkerService extends Service {
  @service appEvents;
  @service siteSettings;
  @service capabilities;
  @service session;

  worker = null;
  workerUrl = getAbsoluteURL("/javascripts/media-optimization-worker.js");
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
    if (!/(\.|\/)(jpe?g|png)$/i.test(file.type)) {
      return Promise.resolve();
    }
    if (
      file.size <
      this.siteSettings
        .composer_media_optimization_image_bytes_optimization_threshold
    ) {
      this.logIfDebug(
        `The file ${file.name} was less than the image optimization bytes threshold (${this.siteSettings.composer_media_optimization_image_bytes_optimization_threshold} bytes), skipping.`,
        file
      );
      return Promise.resolve();
    }
    await this.ensureAvailableWorker();

    // eslint-disable-next-line no-async-promise-executor
    return new Promise(async (resolve) => {
      this.logIfDebug(`Transforming ${file.name}`);

      this.currentComposerUploadData = data;
      this.promiseResolvers[file.id] = resolve;

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
          settings: {
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
              this.siteSettings
                .composer_media_optimization_image_resize_linear_rgb,
            encode_quality:
              this.siteSettings
                .composer_media_optimization_image_encode_quality,
            debug_mode:
              this.siteSettings.composer_media_optimization_debug_mode,
            mediaOptimizationBundle: this.session.mediaOptimizationBundle,
          },
        },
        [imageData.data.buffer]
      );
      this.workerPendingCount++;
    });
  }

  async ensureAvailableWorker() {
    if (this.worker && this.workerInstalled) {
      return Promise.resolve();
    }
    if (this.installPromise) {
      return this.installPromise;
    }
    return this.install();
  }

  async install() {
    this.installPromise = new Promise((resolve, reject) => {
      this.afterInstalled = resolve;
      this.failedInstall = reject;
      this.logIfDebug("Installing worker.");
      this.startWorker();
      this.registerMessageHandler();
      this.worker.postMessage({
        type: "install",
        settings: {
          mediaOptimizationBundle: this.session.mediaOptimizationBundle,
        },
      });

      // new Worker(workerUrl) can hang indefinitely in some cases, so we wait
      // and see if the worker manages to install in a reasonable time. If not,
      // we reject the install promise and clean up.
      setTimeout(() => {
        if (!this.workerInstalled) {
          this.failInstall("Worker install timed out.");
        }
      }, WORKER_INSTALL_TIMEOUT_MS);

      this.appEvents.on("composer:closed", this, "stopWorker");
    });

    return this.installPromise;
  }

  startWorker() {
    this.logIfDebug("Starting media-optimization-worker");
    try {
      // TODO come up with a workaround for FF that lacks type: module support
      this.worker = new Worker(this.workerUrl);
    } catch (err) {
      this.failInstall("Error starting worker:", err);
    }
  }

  failInstall(message, err = null) {
    this.logIfDebug(message, err);
    this.failedInstall(err);
    this.cleanupInstallPromises();
  }

  stopWorker() {
    if (this.worker) {
      this.logIfDebug("Stopping media-optimization-worker...");
      this.workerInstalled = false;
      this.worker.terminate();
      this.worker = null;
      this.workerDoneCount = 0;
    }
    this.workerPendingCount = 0;
  }

  registerMessageHandler() {
    this.worker.onmessage = (workerMessage) => {
      switch (workerMessage.data.type) {
        case "file":
          let optimizedFile = new File(
            [workerMessage.data.file],
            workerMessage.data.fileName,
            {
              type: "image/jpeg",
            }
          );
          this.logIfDebug(
            `Finished optimization of ${optimizedFile.name} new size: ${optimizedFile.size}.`
          );

          this.promiseResolvers[workerMessage.data.fileId](optimizedFile);

          this.workerDoneCount++;
          this.workerPendingCount--;
          if (this.workerDoneCount > 4 && this.workerPendingCount === 0) {
            this.logIfDebug("Terminating worker to release memory in WASM.");
            this.stopWorker();
          }

          break;
        case "error":
          this.logIfDebug(
            `Handling error message from image optimization for ${workerMessage.data.fileName}.`
          );

          if (this.stopWorkerOnError) {
            this.stopWorker();
          }

          this.promiseResolvers[workerMessage.data.fileId]();
          this.workerPendingCount--;
          break;
        case "installed":
          this.logIfDebug("Worker installed.");
          this.workerInstalled = true;
          this.afterInstalled();
          this.cleanupInstallPromises();
          break;
        case "installFailed":
          this.failInstall(
            "Worker failed to install.",
            workerMessage.data.errorMessage
          );
          break;
        default:
          this.logIfDebug(`Sorry, we are out of ${workerMessage}.`);
      }
    };
  }

  cleanupInstallPromises() {
    this.afterInstalled = null;
    this.failedInstall = null;
    this.installPromise = null;
  }

  logIfDebug(...messages) {
    if (this.siteSettings.composer_media_optimization_debug_mode) {
      // eslint-disable-next-line no-console
      console.log("[media-optimization-worker]", ...messages);
    }
  }
}
