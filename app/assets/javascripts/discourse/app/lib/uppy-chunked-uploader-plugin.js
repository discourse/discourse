import { UploaderPlugin } from "discourse/lib/uppy-plugin-base";
import getURL from "discourse-common/lib/get-url";
import { Promise } from "rsvp";
import UppyChunkedUpload from "discourse/lib/uppy-chunked-upload";
import RateLimitedQueue from "discourse/lib/rate-limited-queue";
// const { Socket, Provider, RequestClient } = require('@uppy/companion-client')
// const EventTracker = require('@uppy/utils/lib/EventTracker')
// const emitSocketProgress = require('@uppy/utils/lib/emitSocketProgress')
// const getSocketHost = require('@uppy/utils/lib/getSocketHost')
// const { RateLimitedQueue } = require('@uppy/utils/lib/RateLimitedQueue')
// const Uploader = require('./MultichunkUploader')
class EventTracker {
  constructor(emitter) {
    this.emitter = emitter;
    this.events = [];
  }

  on(event, fn) {
    this.events.push([event, fn]);
    return this.emitter.on(event, fn);
  }

  remove() {
    for (const [event, fn] of this.events.splice(0)) {
      this.emitter.off(event, fn);
    }
  }
}

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

    this.requests = new RateLimitedQueue(this.opts.limit);

    this.uploaders = Object.create(null);
    this.uploaderEvents = Object.create(null);
  }

  /**
   * Clean up all references for a file's upload: the MultichunkUploader instance,
   * any events related to the file, and the Companion WebSocket connection.
   *
   * Set `opts.abort` to tell S3 that the multichunk upload is cancelled and must be removed.
   * This should be done when the user cancels the upload, not when the upload is completed or errored.
   */
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

        queuedRequest.done();
        this._resetUploaderReferences(file.id);
        reject(err);
      };

      const onSuccess = () => {
        queuedRequest.done();
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

        onProgress,
        onError,
        onSuccess,
        onChunkComplete,

        limit: this.opts.limit || 1,
        retryDelays: this.opts.retryDelays || [],
        method: this.method,
        url: this.url,
        headers: this.opts.headers,
      });

      this.uploaders[file.id] = upload;
      this.uploaderEvents[file.id] = new EventTracker(this.uppy);

      let queuedRequest = this.requests.run(() => {
        if (!file.isPaused) {
          upload.start();
        }
        // Don't do anything here, the caller will take care of cancelling the upload itself
        // using _resetUploaderReferences(). This is because _resetUploaderReferences() has to be
        // called when this request is still in the queue, and has not been started yet, too. At
        // that point this cancellation function is not going to be called.
        return () => {};
      });

      this._onFileRemove(file.id, (removed) => {
        queuedRequest.abort();
        this._resetUploaderReferences(file.id, { abort: true });
        resolve(`upload ${removed.id} was removed`);
      });

      this._onCancelAll(file.id, () => {
        queuedRequest.abort();
        this._resetUploaderReferences(file.id, { abort: true });
        resolve(`upload ${file.id} was canceled`);
      });

      this._onFilePause(file.id, (isPaused) => {
        if (isPaused) {
          // Remove this file from the queue so another file can start in its place.
          queuedRequest.abort();
          upload.pause();
        } else {
          // Resuming an upload should be queued, else you could pause and then
          // resume a queued upload to make it skip the queue.
          queuedRequest.abort();
          queuedRequest = this.requests.run(() => {
            upload.start();
            return () => {};
          });
        }
      });

      this._onPauseAll(file.id, () => {
        queuedRequest.abort();
        upload.pause();
      });

      this._onResumeAll(file.id, () => {
        queuedRequest.abort();
        if (file.error) {
          upload.abort();
        }
        queuedRequest = this.requests.run(() => {
          upload.start();
          return () => {};
        });
      });

      // Don't double-emit upload-started for Golden Retriever-restored files that were already started
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
        // const isPaused = this.uppy.pauseResume(fileID)
        cb(isPaused);
      }
    });
  }

  _onRetry(fileID, cb) {
    this.uploaderEvents[fileID].on("upload-retry", (targetFileID) => {
      if (fileID === targetFileID) {
        cb();
      }
    });
  }

  _onRetryAll(fileID, cb) {
    this.uploaderEvents[fileID].on("retry-all", () => {
      if (!this.uppy.getFile(fileID)) {
        return;
      }
      cb();
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
    if (fileIDs.length === 0) {
      return Promise.resolve();
    }

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
