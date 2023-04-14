import { Promise } from "rsvp";
import delay from "@uppy/utils/lib/delay";
import {
  AbortController,
  createAbortError,
} from "@uppy/utils/lib/AbortController";

const MB = 1024 * 1024;

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

/**
 * Used mainly as a replacement for Resumable.js, using code cribbed from
 * uppy's S3 Multipart class, which we mainly use the chunking algorithm
 * and retry/abort functions of. The _buildFormData function is the one
 * which shapes the data into the same parameters as Resumable.js used.
 *
 * See the UppyChunkedUploader class for the uppy uploader plugin which
 * uses UppyChunkedUpload.
 */
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
    this._initChunks();
  }

  _aborted() {
    return this.abortController.signal.aborted;
  }

  _initChunks() {
    this.chunksInProgress = 0;
    this.chunks = null;
    this.chunkState = null;

    const chunks = [];

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
      bytesUploaded: 0,
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
      if (!state.done && !state.busy) {
        candidates.push(i);
        if (candidates.length >= need) {
          break;
        }
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

  _shouldRetry(err) {
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

  _retryable({ before, attempt, after }) {
    const { retryDelays } = this.options;
    const { signal } = this.abortController;

    if (before) {
      before();
    }

    const doAttempt = (retryAttempt) =>
      attempt().catch((err) => {
        if (this._aborted()) {
          throw createAbortError();
        }

        if (this._shouldRetry(err) && retryAttempt < retryDelays.length) {
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
    this.chunkState[index].bytesUploaded = parseInt(sent, 10);

    const totalUploaded = this.chunkState.reduce(
      (total, chunk) => total + chunk.bytesUploaded,
      0
    );
    this.options.onProgress(totalUploaded, this.file.data.size);
  }

  _onChunkComplete(index) {
    this.chunkState[index].done = true;
    this.options.onChunkComplete(index);
  }

  _uploadChunkBytes(index, url, headers) {
    const body = this.chunks[index];
    const { signal } = this.abortController;

    return new Promise((resolve, reject) => {
      const xhr = new XMLHttpRequest();
      function cleanup() {
        signal.removeEventListener("abort", () => xhr.abort());
      }
      signal.addEventListener("abort", xhr.abort());

      xhr.open(this.options.method || "POST", url, true);
      if (headers) {
        Object.keys(headers).forEach((key) => {
          xhr.setRequestHeader(key, headers[key]);
        });
      }
      xhr.responseType = "text";
      xhr.upload.addEventListener("progress", (ev) => {
        if (!ev.lengthComputable) {
          return;
        }

        this._onChunkProgress(index, ev.loaded, ev.total);
      });

      xhr.addEventListener("abort", () => {
        cleanup();
        this.chunkState[index].busy = false;

        reject(createAbortError());
      });

      xhr.addEventListener("load", (ev) => {
        cleanup();
        this.chunkState[index].busy = false;

        if (ev.target.status < 200 || ev.target.status >= 300) {
          const error = new Error("Non 2xx");
          error.source = ev.target;
          reject(error);
          return;
        }

        // This avoids the net::ERR_OUT_OF_MEMORY in Chromium Browsers.
        this.chunks[index] = null;

        this._onChunkProgress(index, body.size, body.size);

        this._onChunkComplete(index);
        resolve();
      });

      xhr.addEventListener("error", (ev) => {
        cleanup();
        this.chunkState[index].busy = false;

        const error = new Error("Unknown error");
        error.source = ev.target;
        reject(error);
      });

      xhr.send(this._buildFormData(index + 1, body));
    });
  }

  async _completeUpload() {
    this.options.onSuccess();
  }

  _buildFormData(currentChunkNumber, body) {
    const uniqueIdentifier =
      this.file.data.size +
      "-" +
      this.file.data.name.replace(/[^0-9a-zA-Z_-]/gim, "");
    const formData = new FormData();
    formData.append("file", body);
    formData.append("resumableChunkNumber", currentChunkNumber);
    formData.append("resumableCurrentChunkSize", body.size);
    formData.append("resumableChunkSize", this.chunkSize);
    formData.append("resumableTotalSize", this.file.data.size);
    formData.append("resumableFilename", this.file.data.name);
    formData.append("resumableIdentifier", uniqueIdentifier);
    return formData;
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
