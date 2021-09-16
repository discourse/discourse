import { BasePlugin } from "@uppy/core";
import { warn } from "@ember/debug";

export class UppyPluginBase extends BasePlugin {
  constructor(uppy, opts) {
    super(uppy, opts);
    this.id = this.constructor.pluginId;
  }

  _consoleWarn(msg) {
    warn(msg, { id: `discourse.${this.id}` });
  }

  _getFile(fileId) {
    return this.uppy.getFile(fileId);
  }

  _setFileMeta(fileId, meta) {
    this.uppy.setFileMeta(fileId, meta);
  }

  _setFileState(fileId, state) {
    this.uppy.setFileState(fileId, state);
  }
}

export class UploadPreProcessorPlugin extends UppyPluginBase {
  static pluginType = "preprocessor";

  constructor(uppy, opts) {
    super(uppy, opts);
    this.type = this.constructor.pluginType;
  }

  _install(fn) {
    this.uppy.addPreProcessor(fn);
  }

  _uninstall(fn) {
    this.uppy.removePreProcessor(fn);
  }

  _emitProgress(file) {
    this.uppy.emit("preprocess-progress", this.id, file);
  }

  _emitComplete(file) {
    this.uppy.emit("preprocess-complete", this.id, file);
  }
}
