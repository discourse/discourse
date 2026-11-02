import { Promise } from "rsvp";
import { bind } from "discourse/lib/decorators";
import { UploadPreProcessorPlugin } from "discourse/lib/uppy-plugin-base";

export default class UppyMediaOptimization extends UploadPreProcessorPlugin {
  static pluginId = "uppy-media-optimization";

  #settleRemoved = new Map();

  constructor(uppy, opts) {
    super(uppy, opts);
    this.optimizeFn = opts.optimizeFn;
    this.cancelFn = opts.cancelFn;

    // mobile devices have limited processing power, so we only enable
    // running media optimization in parallel when we are sure the user
    // is not on a mobile device. otherwise we just process the images
    // serially.
    this.runParallel = opts.runParallel || false;
  }

  install() {
    if (this.runParallel) {
      this._install(this._optimizeParallel);
    } else {
      this._install(this._optimizeSerial);
    }
    this.uppy.on("file-removed", this._onFileRemoved);
  }

  uninstall() {
    if (this.runParallel) {
      this._uninstall(this._optimizeParallel);
    } else {
      this._uninstall(this._optimizeSerial);
    }
    this.uppy.off("file-removed", this._onFileRemoved);
  }

  // Don't keep the rest of the batch waiting on a file that was cancelled.
  @bind
  _onFileRemoved(file) {
    this.#settleRemoved.get(file.id)?.();
    this.cancelFn?.(file.id);
  }

  @bind
  _optimizeFile(fileId) {
    let file = this._getFile(fileId);
    if (!file) {
      return Promise.resolve();
    }

    this._emitProgress(file);

    const removed = new Promise((resolve) =>
      this.#settleRemoved.set(fileId, resolve)
    );

    return Promise.race([
      this.optimizeFn(file, { stopWorkerOnError: !this.runParallel }),
      removed,
    ])
      .then((optimizedFile) => {
        if (!this._getFile(fileId)) {
          return;
        }

        let skipped = false;
        if (!optimizedFile) {
          this._consoleWarn(
            "Nothing happened, possible error or other restriction, or the file format is not a valid one for compression."
          );
          skipped = true;
        } else {
          this._setFileState(fileId, {
            data: optimizedFile,
            size: optimizedFile.size,
          });
        }
        this._emitComplete(file, skipped);
      })
      .catch((err) => {
        this._consoleWarn(err);
        this._emitComplete(file);
      })
      .finally(() => this.#settleRemoved.delete(fileId));
  }

  @bind
  _optimizeParallel(fileIds) {
    return Promise.all(fileIds.map(this._optimizeFile));
  }

  @bind
  async _optimizeSerial(fileIds) {
    let optimizeTasks = fileIds.map(
      (fileId) => () => this._optimizeFile(fileId)
    );

    for (const task of optimizeTasks) {
      await task();
    }
  }
}
