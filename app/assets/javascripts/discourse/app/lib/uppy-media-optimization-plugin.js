import { BasePlugin } from "@uppy/core";
import { warn } from "@ember/debug";
import { Promise } from "rsvp";

export default class UppyMediaOptimization extends BasePlugin {
  constructor(uppy, opts) {
    super(uppy, opts);
    this.id = opts.id || "uppy-media-optimization";

    this.type = "preprocessor";
    this.optimizeFn = opts.optimizeFn;
    this.pluginClass = this.constructor.name;

    // mobile devices have limited processing power, so we only enable
    // running media optimization in parallel when we are sure the user
    // is not on a mobile device. otherwise we just process the images
    // serially.
    this.runParallel = opts.runParallel || false;
  }

  _optimizeFile(fileId) {
    let file = this.uppy.getFile(fileId);

    this.uppy.emit("preprocess-progress", this.pluginClass, file);

    return this.optimizeFn(file, { stopWorkerOnError: !this.runParallel })
      .then((optimizedFile) => {
        if (!optimizedFile) {
          warn("Nothing happened, possible error or other restriction.", {
            id: "discourse.uppy-media-optimization",
          });
        } else {
          this.uppy.setFileState(fileId, {
            data: optimizedFile,
            size: optimizedFile.size,
          });
        }
        this.uppy.emit("preprocess-complete", this.pluginClass, file);
      })
      .catch((err) => {
        warn(err, { id: "discourse.uppy-media-optimization" });
        this.uppy.emit("preprocess-complete", this.pluginClass, file);
      });
  }

  _optimizeParallel(fileIds) {
    return Promise.all(fileIds.map(this._optimizeFile.bind(this)));
  }

  async _optimizeSerial(fileIds) {
    let optimizeTasks = fileIds.map((fileId) => () =>
      this._optimizeFile.call(this, fileId)
    );

    for (const task of optimizeTasks) {
      await task();
    }
  }

  install() {
    if (this.runParallel) {
      this.uppy.addPreProcessor(this._optimizeParallel.bind(this));
    } else {
      this.uppy.addPreProcessor(this._optimizeSerial.bind(this));
    }
  }

  uninstall() {
    if (this.runParallel) {
      this.uppy.removePreProcessor(this._optimizeParallel.bind(this));
    } else {
      this.uppy.removePreProcessor(this._optimizeSerial.bind(this));
    }
  }
}
