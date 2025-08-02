import { next } from "@ember/runloop";
import EventTracker from "@uppy/utils/lib/EventTracker";
import { Promise } from "rsvp";
import getURL from "discourse/lib/get-url";
import UppyChunkedUpload from "discourse/lib/uppy-chunked-upload";
import { UploaderPlugin } from "discourse/lib/uppy-plugin-base";

// Limited use uppy uploader function to replace Resumable.js, which
// is only used by the local backup uploader at this point in time,
// and has been that way for many years. Uses the skeleton of uppy's
// AwsS3Multipart uploader plugin to provide a similar API, with unnecessary
// code removed.
//
// See also UppyChunkedUpload class for more detail.
export default class UppyChunkedUploader extends UploaderPlugin {
  static pluginId = "uppy-chunked-uploader";

  constructor(uppy, opts) {
    super(uppy, opts);
    const defaultOptions = {
      limit: 0,
      retryDelays: [0, 1000, 3000, 5000],
    };

    this.opts = { ...defaultOptions, ...opts };
    this.url = getURL(opts.url);
    this.method = opts.method || "POST";

    this.uploaders = Object.create(null);
    this.uploaderEvents = Object.create(null);
  }

  _resetUploaderReferences(fileID, opts = {}) {
    if (this.uploaders[fileID]) {
      this.uploaders[fileID].abort({ really: opts.abort || false });
      this.uploaders[fileID] = null;
    }
    if (this.uploaderEvents[fileID]) {
      this.uploaderEvents[fileID].remove();
      this.uploaderEvents[fileID] = null;
    }
  }

  _uploadFile(file) {
    return new Promise((resolve, reject) => {
      const onStart = () => {
        this.uppy.emit("upload-started", file);
      };

      const onProgress = (bytesUploaded, bytesTotal) => {
        this.uppy.emit("upload-progress", file, {
          uploader: this,
          bytesUploaded,
          bytesTotal,
        });
      };

      const onError = (err) => {
        this.uppy.log(err);
        this.uppy.emit("upload-error", file, err);

        this._resetUploaderReferences(file.id);
        reject(err);
      };

      const onSuccess = () => {
        this._resetUploaderReferences(file.id);

        const cFile = this.uppy.getFile(file.id);
        const uploadResponse = {};
        this.uppy.emit("upload-success", cFile || file, uploadResponse);

        resolve(upload);
      };

      const onChunkComplete = (chunk) => {
        const cFile = this.uppy.getFile(file.id);
        if (!cFile) {
          return;
        }

        this.uppy.emit("chunk-uploaded", cFile, chunk);
      };

      const upload = new UppyChunkedUpload(file, {
        getChunkSize: this.opts.getChunkSize
          ? this.opts.getChunkSize.bind(this)
          : null,

        onStart,
        onProgress,
        onChunkComplete,
        onSuccess,
        onError,

        limit: this.opts.limit || 5,
        retryDelays: this.opts.retryDelays || [],
        method: this.method,
        url: this.url,
        headers: this.opts.headers,
      });

      this.uploaders[file.id] = upload;
      this.uploaderEvents[file.id] = new EventTracker(this.uppy);

      next(() => {
        if (!file.isPaused) {
          upload.start();
        }
      });

      this._onFileRemove(file.id, (removed) => {
        this._resetUploaderReferences(file.id, { abort: true });
        resolve(`upload ${removed.id} was removed`);
      });

      this._onCancelAll(file.id, () => {
        this._resetUploaderReferences(file.id, { abort: true });
        resolve(`upload ${file.id} was canceled`);
      });

      this._onFilePause(file.id, (isPaused) => {
        if (isPaused) {
          upload.pause();
        } else {
          next(() => {
            upload.start();
          });
        }
      });

      this._onPauseAll(file.id, () => {
        upload.pause();
      });

      this._onResumeAll(file.id, () => {
        if (file.error) {
          upload.abort();
        }
        next(() => {
          upload.start();
        });
      });

      // Don't double-emit upload-started for restored files that were already started
      if (!file.progress.uploadStarted || !file.isRestored) {
        this.uppy.emit("upload-started", file);
      }
    });
  }

  _onFileRemove(fileID, cb) {
    this.uploaderEvents[fileID].on("file-removed", (file) => {
      if (fileID === file.id) {
        cb(file.id);
      }
    });
  }

  _onFilePause(fileID, cb) {
    this.uploaderEvents[fileID].on("upload-pause", (targetFileID, isPaused) => {
      if (fileID === targetFileID) {
        cb(isPaused);
      }
    });
  }

  _onPauseAll(fileID, cb) {
    this.uploaderEvents[fileID].on("pause-all", () => {
      if (!this.uppy.getFile(fileID)) {
        return;
      }
      cb();
    });
  }

  _onCancelAll(fileID, cb) {
    this.uploaderEvents[fileID].on("cancel-all", () => {
      if (!this.uppy.getFile(fileID)) {
        return;
      }
      cb();
    });
  }

  _onResumeAll(fileID, cb) {
    this.uploaderEvents[fileID].on("resume-all", () => {
      if (!this.uppy.getFile(fileID)) {
        return;
      }
      cb();
    });
  }

  _upload(fileIDs) {
    const promises = fileIDs.map((id) => {
      const file = this.uppy.getFile(id);
      return this._uploadFile(file);
    });

    return Promise.all(promises);
  }

  install() {
    this._install(this._upload.bind(this));
  }

  uninstall() {
    this._uninstall(this._upload.bind(this));
  }
}
