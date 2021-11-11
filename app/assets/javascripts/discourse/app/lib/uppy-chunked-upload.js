// const { AbortController, createAbortError } = require('@uppy/utils/lib/AbortController')
import { Promise } from "rsvp";
// const delay = require('@uppy/utils/lib/delay')

const MB = 1024 * 1024;

const createAbortError = (message = "Aborted") =>
  new DOMException(message, "AbortError");
const defaultOptions = {
  limit: 5,
  retryDelays: [0, 1000, 3000, 5000],
  getChunkSize() {
    return 5 * MB;
  },
  onStart() {},
  onProgress() {},
  onChunkComplete() {},
  onSuccess() {},
  onError(err) {
    throw err;
  },
};
function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export default class UppyChunkedUpload {
  constructor(file, options) {
    this.options = {
      ...defaultOptions,
      ...options,
    };
    this.file = file;

    if (!this.options.getChunkSize) {
      this.options.getChunkSize = defaultOptions.getChunkSize;
      this.chunkSize = this.options.getChunkSize(this.file);
    }

    this.abortController = new AbortController();
    this.chunksInProgress = 0;
    this.chunks = null;
    this.chunkState = null;

    this._initChunks();
  }

  /**
   * Was this upload aborted?
   *
   * If yes, we may need to throw an AbortError.
   *
   * @returns {boolean}
   */
  _aborted() {
    return this.abortController.signal.aborted;
  }

  _initChunks() {
    const chunks = [];

    // Upload zero-sized files in one zero-sized chunk
    if (this.file.size === 0) {
      chunks.push(this.file.data);
    } else {
      for (let i = 0; i < this.file.data.size; i += this.chunkSize) {
        const end = Math.min(this.file.data.size, i + this.chunkSize);
        chunks.push(this.file.data.slice(i, end));
      }
    }

    this.chunks = chunks;
    this.chunkState = chunks.map(() => ({
      uploaded: 0,
      busy: false,
      done: false,
    }));
  }

  _createUpload() {
    if (this._aborted()) {
      throw createAbortError();
    }
    this.options.onStart();
    this._uploadChunks();
  }

  _uploadChunks() {
    if (this.chunkState.every((state) => state.done)) {
      this._completeUpload();
      return;
    }

    // For a 100MB file, with the default min chunk size of 5MB and a limit of 10:
    //
    // Total 20 chunks
    // ---------
    // Need 1 is 10
    // Need 2 is 5
    // Need 3 is 5
    const need = this.options.limit - this.chunksInProgress;
    const completeChunks = this.chunkState.filter((state) => state.done).length;
    const remainingChunks = this.chunks.length - completeChunks;
    let minNeeded = Math.ceil(this.options.limit / 2);
    if (minNeeded > remainingChunks) {
      minNeeded = remainingChunks;
    }
    if (need < minNeeded) {
      return;
    }

    const candidates = [];
    for (let i = 0; i < this.chunkState.length; i++) {
      const state = this.chunkState[i];
      // eslint-disable-next-line no-continue
      if (state.done || state.busy) {
        continue;
      }

      candidates.push(i);
      if (candidates.length >= need) {
        break;
      }
    }
    if (candidates.length === 0) {
      return;
    }

    candidates.forEach((index) => {
      this._uploadChunkRetryable(index).then(
        () => {
          this._uploadChunks();
        },
        (err) => {
          this._onError(err);
        }
      );
    });
  }

  _retryable({ before, attempt, after }) {
    const { retryDelays } = this.options;
    const { signal } = this.abortController;

    if (before) {
      before();
    }

    function shouldRetry(err) {
      if (err.source && typeof err.source.status === "number") {
        const { status } = err.source;
        // 0 probably indicates network failure
        return (
          status === 0 ||
          status === 409 ||
          status === 423 ||
          (status >= 500 && status < 600)
        );
      }
      return false;
    }

    const doAttempt = (retryAttempt) =>
      attempt().catch((err) => {
        if (this._aborted()) {
          throw createAbortError();
        }

        if (shouldRetry(err) && retryAttempt < retryDelays.length) {
          return delay(retryDelays[retryAttempt], { signal }).then(() =>
            doAttempt(retryAttempt + 1)
          );
        }
        throw err;
      });

    return doAttempt(0).then(
      (result) => {
        if (after) {
          after();
        }
        return result;
      },
      (err) => {
        if (after) {
          after();
        }
        throw err;
      }
    );
  }

  _uploadChunkRetryable(index) {
    return this._retryable({
      before: () => {
        this.chunksInProgress += 1;
      },
      attempt: () => this._uploadChunk(index),
      after: () => {
        this.chunksInProgress -= 1;
      },
    });
  }
  // filename = params.fetch(:resumableFilename)
  // total_size = params.fetch(:resumableTotalSize).to_i
  // identifier = params.fetch(:resumableIdentifier)
  // file = params.fetch(:file)
  // chunk_number = params.fetch(:resumableChunkNumber).to_i
  // chunk_size = params.fetch(:resumableChunkSize).to_i
  // current_chunk_size = params.fetch(:resumableCurrentChunkSize).to_i
  //
  // these are sent in querystring params AND form data for some reason??
  // http://localhost:4200/admin/backups/upload?resumableChunkNumber=16&resumableChunkSize=1048576&resumableCurrentChunkSize=1048576&resumableTotalSize=137951695&resumableType=application%2Fgzip&resumableIdentifier=137951695-testbackup1targz&resumableFilename=testbackup1.tar.gz&resumableRelativePath=testbackup1.tar.gz&resumableTotalChunks=131
  //
  // form data
  // resumableChunkNumber: 66
  // resumableChunkSize: 1048576
  // resumableCurrentChunkSize: 1048576
  // resumableTotalSize: 137951695
  // resumableType: application/gzip
  // resumableIdentifier: 137951695-testbackup1targz
  // resumableFilename: testbackup1.tar.gz
  // resumableRelativePath: testbackup1.tar.gz
  // resumableTotalChunks: 131
  // file: (binary)
  //
  // // TODO (martin) (Figure out how to build up this form data)

  _uploadChunk(index) {
    this.chunkState[index].busy = true;

    if (this._aborted()) {
      this.chunkState[index].busy = false;
      throw createAbortError();
    }

    return this._uploadChunkBytes(
      index,
      this.options.url,
      this.options.headers
    );
  }

  _onChunkProgress(index, sent) {
    this.chunkState[index].uploaded = parseInt(sent, 10);

    const totalUploaded = this.chunkState.reduce((n, c) => n + c.uploaded, 0);
    this.options.onProgress(totalUploaded, this.file.data.size);
  }

  _onChunkComplete(index) {
    this.chunkState[index].done = true;
  }

  _uploadChunkBytes(index, url, headers) {
    const body = this.chunks[index];
    const { signal } = this.abortController;

    let defer;
    const promise = new Promise((resolve, reject) => {
      defer = { resolve, reject };
    });

    const xhr = new XMLHttpRequest();
    xhr.open(this.options.method || "POST", url, true);
    if (headers) {
      Object.keys(headers).forEach((key) => {
        xhr.setRequestHeader(key, headers[key]);
      });
    }
    xhr.responseType = "text";

    function cleanup() {
      // eslint-disable-next-line no-use-before-define
      signal.removeEventListener("abort", onabort);
    }
    function onabort() {
      xhr.abort();
    }
    signal.addEventListener("abort", onabort);

    xhr.upload.addEventListener("progress", (ev) => {
      if (!ev.lengthComputable) {
        return;
      }

      this._onChunkProgress(index, ev.loaded, ev.total);
    });

    xhr.addEventListener("abort", () => {
      cleanup();
      this.chunkState[index].busy = false;

      defer.reject(createAbortError());
    });

    xhr.addEventListener("load", (ev) => {
      cleanup();
      this.chunkState[index].busy = false;

      if (ev.target.status < 200 || ev.target.status >= 300) {
        const error = new Error("Non 2xx");
        error.source = ev.target;
        defer.reject(error);
        return;
      }

      // This avoids the net::ERR_OUT_OF_MEMORY in Chromium Browsers.
      this.chunks[index] = null;

      this._onChunkProgress(index, body.size, body.size);

      this._onChunkComplete(index);
      defer.resolve();
    });

    xhr.addEventListener("error", (ev) => {
      cleanup();
      this.chunkState[index].busy = false;

      const error = new Error("Unknown error");
      error.source = ev.target;
      defer.reject(error);
    });

    const uniqueIdentifier =
      this.file.data.size +
      "-" +
      this.file.data.name.replace(/[^0-9a-zA-Z_-]/gim, "");

    const chunkNumber = index + 1;
    const formData = new FormData();
    formData.append("file", body);
    formData.append("resumableChunkNumber", chunkNumber);
    formData.append("resumableCurrentChunkSize", body.size);
    formData.append("resumableChunkSize", this.chunkSize);
    formData.append("resumableTotalSize", this.file.data.size);
    formData.append("resumableFilename", this.file.data.name);
    formData.append("resumableIdentifier", uniqueIdentifier);
    xhr.send(formData);

    return promise;
  }

  // form data
  // resumableChunkNumber: 66
  // resumableChunkSize: 1048576
  // resumableCurrentChunkSize: 1048576
  // resumableTotalSize: 137951695
  // resumableType: application/gzip
  // resumableIdentifier: 137951695-testbackup1targz
  // resumableFilename: testbackup1.tar.gz
  // resumableRelativePath: testbackup1.tar.gz
  // resumableTotalChunks: 131
  // file: (binary)

  async _completeUpload() {
    this.options.onSuccess();
  }

  _abortUpload() {
    this.abortController.abort();
  }

  _onError(err) {
    if (err && err.name === "AbortError") {
      return;
    }

    this.options.onError(err);
  }

  start() {
    this._createUpload();
  }

  abort(opts = undefined) {
    if (opts?.really) {
      this._abortUpload();
    }
  }
}
