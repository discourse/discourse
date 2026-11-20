import { setOwner } from "@ember/owner";
import deprecated from "discourse/lib/deprecated";
import UppyUploadDebugging from "./upload-debugging.js";

/**
 * Use this class whenever you need to upload files or images
 * with Uppy. The class makes it easier to tell Uppy to use certain uppy plugins
 * as well as tracking all of the state of preprocessor plugins. For example,
 * you may have multiple preprocessors:
 *
 * - UppyMediaOptimization
 * - UppyChecksum
 *
 * Once installed with useUploadPlugin(PluginClass, opts), we track, for every
 * preprocessor plugin, the files that still need to be run through it. Files
 * are picked up from uppy's "upload" event; files removed from uppy
 * mid-preprocessing stop being waited on, and late events for them are ignored.
 *
 * If you need to do something else on progress or completion of preprocessors,
 * hook into the onPreProcessProgress(callback) or onPreProcessComplete(callback, allCompleteCallback)
 * functions. Note the onPreProcessComplete function takes a second callback
 * that is fired only when _all_ of the files have been preprocessed for all
 * preprocessor plugins.
 *
 * To completely reset the preprocessor state for all plugins, call resetPreProcessors.
 *
 * See ComposerUploadUppy for an example of a component using this class.
 */
export default class UppyWrapper {
  debug;
  uppyInstance;

  /** @type {Record<string, Set<string>>} pending file ids per preprocessor */
  #preProcessorStatus = {};
  #allCompleteCallbacks = [];
  #trackedInstance = null;

  constructor(owner) {
    setOwner(this, owner);
    this.debug = new UppyUploadDebugging(owner);
  }

  useUploadPlugin(pluginClass, opts = {}) {
    if (!this.uppyInstance) {
      return;
    }

    this.#trackUploads();

    if (!pluginClass.pluginId) {
      throw new Error(
        "The uppy plugin should have a static pluginId that is used to uniquely identify it."
      );
    }

    if (
      !pluginClass.pluginType ||
      !["preprocessor", "uploader"].includes(pluginClass.pluginType)
    ) {
      throw new Error(
        `The uppy plugin ${pluginClass.pluginId} should have a static pluginType that should be preprocessor or uploader`
      );
    }

    this.uppyInstance.use(
      pluginClass,
      Object.assign(opts, {
        id: pluginClass.pluginId,
        type: pluginClass.pluginType,
      })
    );

    if (pluginClass.pluginType === "preprocessor") {
      this.#preProcessorStatus[pluginClass.pluginId] = new Set();
    }
  }

  // NOTE: This and onPreProcessComplete will need to be tweaked
  // if we ever add support for "determinate" preprocessors for uppy, which
  // means the progress will have a value rather than a started/complete
  // state ("indeterminate").
  //
  // See: https://uppy.io/docs/writing-plugins/#Progress-events
  onPreProcessProgress(callback) {
    this.#trackUploads();
    this.uppyInstance.on("preprocess-progress", (file, progress, pluginId) => {
      if (!this.#isPending(pluginId, file)) {
        return;
      }

      this.debug.log(`[${pluginId}] processing file ${file.name} (${file.id})`);

      callback(file);
    });
  }

  onPreProcessComplete(callback, allCompleteCallback = null) {
    this.#trackUploads();
    if (allCompleteCallback) {
      this.#allCompleteCallbacks.push(allCompleteCallback);
    }

    this.uppyInstance.on("preprocess-complete", (file, skipped, pluginId) => {
      if (!this.#isPending(pluginId, file)) {
        return;
      }

      this.debug.log(
        `[${pluginId}] ${skipped ? "skipped" : "completed"} processing file ${
          file.name
        } (${file.id})`
      );

      callback(file);

      this.#preProcessorStatus[pluginId].delete(file.id);
      this.#notifyIfAllComplete();
    });
  }

  resetPreProcessors() {
    this.#eachPreProcessor((pluginId) => {
      this.#preProcessorStatus[pluginId] = new Set();
    });
  }

  addNeedProcessing() {
    deprecated(
      "`UppyWrapper#addNeedProcessing` is no longer needed; files are tracked from uppy's `upload` event.",
      { id: "discourse.uppy-wrapper-add-need-processing", since: "2026.10.0" }
    );
  }

  // The wrapper outlives its Uppy instance, which is rebuilt whenever the
  // editor is set up again, so tracking starts over for each instance.
  #trackUploads() {
    if (this.#trackedInstance === this.uppyInstance) {
      return;
    }
    this.#trackedInstance = this.uppyInstance;
    this.#preProcessorStatus = {};
    this.#allCompleteCallbacks = [];

    this.uppyInstance.on("upload", (uploadId, files) => {
      this.#eachPreProcessor((pluginId, pendingFileIds) => {
        files.forEach((file) => pendingFileIds.add(file.id));
      });
    });

    this.uppyInstance.on("file-removed", (file) => {
      let wasPending = false;
      this.#eachPreProcessor((pluginId, pendingFileIds) => {
        wasPending = pendingFileIds.delete(file.id) || wasPending;
      });

      // Removing the last file is a cancel-all, which consumers reset on themselves
      if (wasPending && this.uppyInstance.getFiles().length > 0) {
        this.#notifyIfAllComplete();
      }
    });
  }

  #eachPreProcessor(cb) {
    for (const [pluginId, pendingFileIds] of Object.entries(
      this.#preProcessorStatus
    )) {
      cb(pluginId, pendingFileIds);
    }
  }

  #isPending(pluginId, file) {
    return !!file && !!this.#preProcessorStatus[pluginId]?.has(file.id);
  }

  #notifyIfAllComplete() {
    const allComplete = Object.values(this.#preProcessorStatus).every(
      (pendingFileIds) => pendingFileIds.size === 0
    );

    if (allComplete) {
      this.debug.log("[uppy] All upload preprocessors complete!");
      this.#allCompleteCallbacks.forEach((callback) => callback());
    }
  }
}
