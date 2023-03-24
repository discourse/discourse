import Mixin from "@ember/object/mixin";
import UploadDebugging from "discourse/mixins/upload-debugging";

/**
 * Use this mixin with any component that needs to upload files or images
 * with Uppy. This mixin makes it easier to tell Uppy to use certain uppy plugins
 * as well as tracking all of the state of preprocessor plugins. For example,
 * you may have multiple preprocessors:
 *
 * - UppyMediaOptimization
 * - UppyChecksum
 *
 * Once installed with _useUploadPlugin(PluginClass, opts), we track the following
 * status for every preprocessor plugin:
 *
 * - needProcessing - The total number of files that have been added to uppy that
 *                    will need to be run through the preprocessor plugins.
 * - activeProcessing - The number of files that are currently being processed,
 *                      which is determined by the preprocess-progress event.
 * - completeProcessing - The number of files that have completed being processed,
 *                        which is determined by the preprocess-complete event.
 * - allComplete - Whether all files have completed the preprocessing for the plugin.
 *
 * There is a caveat - you must call _addNeedProcessing(data.fileIDs.length) when
 * handling the "upload" event with uppy, otherwise this mixin does not know how
 * many files need to be processed.
 *
 * If you need to do something else on progress or completion of preprocessors,
 * hook into the _onPreProcessProgress(callback) or _onPreProcessComplete(callback, allCompleteCallback)
 * functions. Note the _onPreProcessComplete function takes a second callback
 * that is fired only when _all_ of the files have been preprocessed for all
 * preprocessor plugins.
 *
 * A preprocessor is considered complete if the completeProcessing count is
 * equal to needProcessing, at which point the allComplete prop is set to true.
 * If all preprocessor plugins have allComplete set to true, then the allCompleteCallback
 * is called for _onPreProcessComplete.
 *
 * To completely reset the preprocessor state for all plugins, call _resetPreProcessors.
 *
 * See ComposerUploadUppy for an example of a component using this mixin.
 */
export default Mixin.create(UploadDebugging, {
  _useUploadPlugin(pluginClass, opts = {}) {
    if (!this._uppyInstance) {
      return;
    }

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

    this._uppyInstance.use(
      pluginClass,
      Object.assign(opts, {
        id: pluginClass.pluginId,
        type: pluginClass.pluginType,
      })
    );

    if (pluginClass.pluginType === "preprocessor") {
      this._trackPreProcessorStatus(pluginClass.pluginId);
    }
  },

  // NOTE: This and _onPreProcessComplete will need to be tweaked
  // if we ever add support for "determinate" preprocessors for uppy, which
  // means the progress will have a value rather than a started/complete
  // state ("indeterminate").
  //
  // See: https://uppy.io/docs/writing-plugins/#Progress-events
  _onPreProcessProgress(callback) {
    this._uppyInstance.on("preprocess-progress", (file, progress, pluginId) => {
      this._consoleDebug(
        `[${pluginId}] processing file ${file.name} (${file.id})`
      );

      this._preProcessorStatus[pluginId].activeProcessing++;

      callback(file);
    });
  },

  _onPreProcessComplete(callback, allCompleteCallback = null) {
    this._uppyInstance.on("preprocess-complete", (file, skipped, pluginId) => {
      this._consoleDebug(
        `[${pluginId}] ${skipped ? "skipped" : "completed"} processing file ${
          file.name
        } (${file.id})`
      );

      callback(file);

      this._completePreProcessing(pluginId, (allComplete) => {
        if (allComplete) {
          this._consoleDebug("[uppy] All upload preprocessors complete!");
          if (allCompleteCallback) {
            allCompleteCallback();
          }
        }
      });
    });
  },

  _resetPreProcessors() {
    this._eachPreProcessor((pluginId) => {
      this._preProcessorStatus[pluginId] = {
        needProcessing: 0,
        activeProcessing: 0,
        completeProcessing: 0,
        allComplete: false,
      };
    });
  },

  _trackPreProcessorStatus(pluginId) {
    if (!this._preProcessorStatus) {
      this._preProcessorStatus = {};
    }
    this._preProcessorStatus[pluginId] = {
      needProcessing: 0,
      activeProcessing: 0,
      completeProcessing: 0,
      allComplete: false,
    };
  },

  _addNeedProcessing(fileCount) {
    this._eachPreProcessor((pluginName, status) => {
      status.needProcessing += fileCount;
      status.allComplete = false;
    });
  },

  _eachPreProcessor(cb) {
    for (const [pluginId, status] of Object.entries(this._preProcessorStatus)) {
      cb(pluginId, status);
    }
  },

  _allPreprocessorsComplete() {
    let completed = [];
    this._eachPreProcessor((pluginId, status) => {
      completed.push(status.allComplete);
    });
    return completed.every(Boolean);
  },

  _completePreProcessing(pluginId, callback) {
    const preProcessorStatus = this._preProcessorStatus[pluginId];
    preProcessorStatus.activeProcessing--;
    preProcessorStatus.completeProcessing++;

    if (
      preProcessorStatus.completeProcessing ===
      preProcessorStatus.needProcessing
    ) {
      preProcessorStatus.allComplete = true;
      preProcessorStatus.needProcessing = 0;
      preProcessorStatus.completeProcessing = 0;

      if (this._allPreprocessorsComplete()) {
        callback(true);
      } else {
        callback(false);
      }
    }
  },
});
