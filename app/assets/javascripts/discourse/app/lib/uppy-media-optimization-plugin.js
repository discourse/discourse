import { Plugin } from "@uppy/core";
import { warn } from "@ember/debug";
import { Promise } from "rsvp";

export default class UppyMediaOptimization extends Plugin {
  constructor(uppy, opts) {
    super(uppy, opts);
    this.id = opts.id || "uppy-media-optimization";

    this.type = "preprocessor";
    this.optimizeFn = opts.optimizeFn;
  }

  optimize(fileIds) {
    let promises = fileIds.map((fileId) => {
      let file = this.uppy.getFile(fileId);

      this.uppy.emit("preprocess-progress", file, {
        mode: "indeterminate",
        message: "optimizing images",
      });

      return this.optimizeFn(file)
        .then((optimizedFile) => {
          if (!optimizedFile) {
            warn("Nothing happened, possible error or other restriction.", {
              id: "discourse.uppy-media-optimization",
            });
          } else {
            this.uppy.setFileState(fileId, { data: optimizedFile });
          }
          this.uppy.emit("preprocess-complete", file);
        })
        .catch((err) => warn(err, { id: "discourse.uppy-media-optimization" }));
    });

    return Promise.all(promises);
  }

  install() {
    this.uppy.addPreProcessor(this.optimize.bind(this));
  }

  uninstall() {
    this.uppy.removePreProcessor(this.optimize.bind(this));
  }
}
