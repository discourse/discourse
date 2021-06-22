import Service from "@ember/service";
import { getOwner } from "@ember/application";
import { Promise } from "rsvp";
import { fileToImageData } from "discourse/lib/media-optimization-utils";
import { getAbsoluteURL, getURLWithCDN } from "discourse-common/lib/get-url";

export default class MediaOptimizationWorkerService extends Service {
  appEvents = getOwner(this).lookup("service:app-events");
  worker = null;
  debugger;
  workerUrl = getAbsoluteURL("/javascripts/media-optimization-worker.js");
  currentComposerUploadData = null;
  currentPromiseResolver = null;

  startWorker() {
    this.worker = new Worker(this.workerUrl); // TODO come up with a workaround for FF that lacks type: module support
  }

  stopWorker() {
    this.worker.terminate();
    this.worker = null;
  }

  ensureAvailiableWorker() {
    if (this.worker === null) {
      this.startWorker();
      this.registerMessageHandler();
      this.appEvents.on("composer:closed", this, "stopWorker");
    }
  }

  logIfDebug(message) {
    if (this.siteSettings.composer_media_optimization_debug_mode) {
      // eslint-disable-next-line no-console
      console.log(message);
    }
  }

  optimizeImage(data) {
    let file = data.files[data.index];
    if (!/(\.|\/)(jpe?g|png|webp)$/i.test(file.type)) {
      return data;
    }
    if (
      file.size <
      this.siteSettings
        .composer_media_optimization_image_kilobytes_optimization_threshold
    ) {
      return data;
    }
    this.ensureAvailiableWorker();
    let p = new Promise(async (resolve) => {
      this.logIfDebug(`Transforming ${file.name}`);

      this.currentComposerUploadData = data;
      this.currentPromiseResolver = resolve;

      const { imageData, width, height, err } = await fileToImageData(file);

      if (err) {
        this.logIfDebug(err);
        return resolve(data);
      }

      this.worker.postMessage(
        {
          type: "compress",
          file: imageData.data.buffer,
          fileName: file.name,
          width: width,
          height: height,
          settings: {
            mozjpeg_script: getURLWithCDN(
              "/javascripts/squoosh/mozjpeg_enc.js"
            ),
            mozjpeg_wasm: getURLWithCDN(
              "/javascripts/squoosh/mozjpeg_enc.wasm"
            ),
            resize_script: getURLWithCDN(
              "/javascripts/squoosh/squoosh_resize.js"
            ),
            resize_wasm: getURLWithCDN(
              "/javascripts/squoosh/squoosh_resize_bg.wasm"
            ),
            resize_threshold: this.siteSettings
              .composer_media_optimization_image_resize_dimensions_threshold,
            resize_target: this.siteSettings
              .composer_media_optimization_image_resize_width_target,
            resize_pre_multiply: this.siteSettings
              .composer_media_optimization_image_resize_pre_multiply,
            resize_linear_rgb: this.siteSettings
              .composer_media_optimization_image_resize_linear_rgb,
            encode_quality: this.siteSettings
              .composer_media_optimization_image_encode_quality,
            debug_mode: this.siteSettings
              .composer_media_optimization_debug_mode,
          },
        },
        [imageData.data.buffer]
      );
    });
    return p;
  }

  registerMessageHandler() {
    this.worker.onmessage = (e) => {
      this.logIfDebug("Main: Message received from worker script");
      this.logIfDebug(e);
      switch (e.data.type) {
        case "file":
          let optimizedFile = new File([e.data.file], `${e.data.fileName}`, {
            type: "image/jpeg",
          });
          this.logIfDebug(
            `Finished optimization of ${optimizedFile.name} new size: ${optimizedFile.size}.`
          );
          let data = this.currentComposerUploadData;
          data.files[data.index] = optimizedFile;
          this.currentPromiseResolver(data);
          break;
        case "error":
          this.stopWorker();
          this.currentPromiseResolver(this.currentComposerUploadData);
          break;
        default:
          this.logIfDebug(`Sorry, we are out of ${e}.`);
      }
    };
  }
}
