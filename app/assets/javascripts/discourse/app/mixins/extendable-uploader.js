import Mixin from "@ember/object/mixin";

export default Mixin.create({
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

  _completePreProcessing(pluginId, callback) {
    const preProcessorStatus = this._preProcessorStatus[pluginId];
    preProcessorStatus.activeProcessing--;
    preProcessorStatus.completeProcessing++;

    if (
      preProcessorStatus.completeProcessing ===
      preProcessorStatus.needProcessing
    ) {
      preProcessorStatus.allComplete = true;

      if (this._allPreprocessorsComplete()) {
        callback(true);
      } else {
        callback(false);
      }
    }
  },

  _onPreProcessProgress(callback) {
    this._uppyInstance.on("preprocess-progress", (pluginId, file) => {
      this._debugLog(`[${pluginId}] processing file ${file.name} (${file.id})`);

      this._preProcessorStatus[pluginId].activeProcessing++;

      callback(file);
    });
  },

  _onPreProcessComplete(callback, allCompleteCallback) {
    this._uppyInstance.on("preprocess-complete", (pluginId, file) => {
      this._debugLog(
        `[${pluginId}] completed processing file ${file.name} (${file.id})`
      );

      callback(file);

      this._completePreProcessing(pluginId, (allComplete) => {
        if (allComplete) {
          this._debugLog("All upload preprocessors complete.");
          allCompleteCallback();
        }
      });
    });
  },
});
