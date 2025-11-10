import { setOwner } from "@ember/owner";
import { debounce } from "@ember/runloop";
import { service } from "@ember/service";
import AwsS3 from "@uppy/aws-s3";
import { Promise } from "rsvp";
import { ajax } from "discourse/lib/ajax";

const RETRY_DELAYS = [0, 1000, 3000, 5000];
const MB = 1024 * 1024;

const s3MultipartMeta = new WeakMap(); // file -> { attempts: { partNumber -> attempts }, signingErrorRaised: boolean, batchSigner: BatchSigner }

export default class UppyS3Multipart {
  @service siteSettings;

  constructor(owner, { uploadRootPath, errorHandler, uppyWrapper }) {
    setOwner(this, owner);
    this.uploadRootPath = uploadRootPath;
    this.uppyWrapper = uppyWrapper;
    this.errorHandler = errorHandler;
  }

  apply(uppyInstance) {
    this.uppyInstance = uppyInstance;

    this.uppyInstance.use(AwsS3, {
      // TODO: using multipart even for tiny files is not ideal. Now that uppy
      // made multipart a simple boolean, rather than a separate plugin, we can
      // consider combining our two S3 implementations and choose the strategy
      // based on file size.
      shouldUseMultipart: true,

      // Number of concurrent part uploads. AWS uses http/1.1,
      // which browsers limit to 6 concurrent connections per host.
      limit: 6,

      retryDelays: RETRY_DELAYS,

      // When we get to really big files, it's better to not have thousands
      // of small chunks, since we don't have a resume functionality if the
      // upload fails. Better to try upload less chunks even if those chunks
      // are bigger.
      getChunkSize(file) {
        if (file.size >= 500 * MB) {
          return 20 * MB;
        } else if (file.size >= 100 * MB) {
          return 10 * MB;
        } else {
          return 5 * MB;
        }
      },

      createMultipartUpload: this.#createMultipartUpload.bind(this),
      completeMultipartUpload: this.#completeMultipartUpload.bind(this),
      abortMultipartUpload: this.#abortMultipartUpload.bind(this),
      signPart: this.#signPart.bind(this),

      // we will need a listParts function at some point when we want to
      // resume multipart uploads; this is used by uppy to figure out
      // what parts are uploaded and which still need to be
    });
  }

  #createMultipartUpload(file) {
    this.uppyInstance.emit("create-multipart", file.id);

    const data = {
      file_name: file.name,
      file_size: file.size,
      upload_type: file.meta.upload_type,
      metadata: file.meta,
    };

    // the sha1 checksum is set by the UppyChecksum plugin, except
    // for in cases where the browser does not support the required
    // crypto mechanisms or an error occurs. it is an additional layer
    // of security, and not required.
    if (file.meta.sha1_checksum) {
      data.metadata = { "sha1-checksum": file.meta.sha1_checksum };
    }

    return ajax(`${this.uploadRootPath}/create-multipart.json`, {
      type: "POST",
      data,
      // uppy is inconsistent, an error here fires the upload-error event
    }).then((responseData) => {
      this.uppyInstance.emit("create-multipart-success", file.id);

      file.meta.unique_identifier = responseData.unique_identifier;
      return {
        uploadId: responseData.external_upload_identifier,
        key: responseData.key,
      };
    });
  }

  #getFileMeta(file) {
    if (s3MultipartMeta.has(file)) {
      return s3MultipartMeta.get(file);
    }

    const fileMeta = {
      attempts: {},
      signingErrorRaised: false,
      batchSigner: new BatchSigner({
        file,
        uploadRootPath: this.uploadRootPath,
      }),
    };

    s3MultipartMeta.set(file, fileMeta);
    return fileMeta;
  }

  async #signPart(file, partData) {
    const fileMeta = this.#getFileMeta(file);

    fileMeta.attempts[partData.partNumber] ??= 0;
    const thisPartAttempts = (fileMeta.attempts[partData.partNumber] += 1);

    this.uppyWrapper.debug.log(
      `[uppy] requesting signature for part ${partData.partNumber} (attempt ${thisPartAttempts})`
    );

    try {
      const url = await fileMeta.batchSigner.signedUrlFor(partData);
      this.uppyWrapper.debug.log(
        `[uppy] signature for part ${partData.partNumber} obtained, continuing.`
      );
      return { url };
    } catch (err) {
      // Uppy doesn't properly bubble errors from failed #signPart, so we call
      // the error handler ourselves after the last failed attempt
      if (
        !fileMeta.signingErrorRaised &&
        thisPartAttempts >= RETRY_DELAYS.length
      ) {
        this.uppyWrapper.debug.log(
          `[uppy] Fetching a signed part URL for ${file.id} failed too many times, raising error.`
        );
        // uppy is inconsistent, an error here does not fire the upload-error event
        this.handleUploadError(file, err);
        fileMeta.signingErrorRaised = true;
      }
      throw err;
    }
  }

  #completeMultipartUpload(file, data) {
    if (file.meta.cancelled) {
      return;
    }

    this.uppyInstance.emit("complete-multipart", file.id);
    const parts = data.parts.map((part) => {
      return { part_number: part.PartNumber, etag: part.ETag };
    });
    return ajax(`${this.uploadRootPath}/complete-multipart.json`, {
      type: "POST",
      contentType: "application/json",
      data: JSON.stringify({
        parts,
        unique_identifier: file.meta.unique_identifier,
        pasted: file.meta.pasted,
        for_private_message: file.meta.for_private_message,
      }),
      // uppy is inconsistent, an error here fires the upload-error event
    }).then((responseData) => {
      this.uppyInstance.emit("complete-multipart-success", file.id);
      return responseData;
    });
  }

  #abortMultipartUpload(file, { key, uploadId }) {
    // if the user cancels the upload before the key and uploadId
    // are stored from the createMultipartUpload response then they
    // will not be set, and we don't have to abort the upload because
    // it will not exist yet
    if (!key || !uploadId) {
      return;
    }

    // this gives us a chance to inspect the upload stub before
    // it is deleted from external storage by aborting the multipart
    // upload; see also ExternalUploadManager
    if (file.meta.error && this.siteSettings.enable_upload_debug_mode) {
      return;
    }

    file.meta.cancelled = true;

    return ajax(`${this.uploadRootPath}/abort-multipart.json`, {
      type: "POST",
      data: {
        external_upload_identifier: uploadId,
      },
      // uppy is inconsistent, an error here does not fire the upload-error event
    }).catch((err) => {
      this.errorHandler(file, err);
    });
  }
}

const BATCH_SIGNER_INITIAL_DEBOUNCE = 50;
const BATCH_SIGNER_REGULAR_DEBOUNCE = 500;

/**
 * This class is responsible for batching requests to the server to sign
 * parts of a multipart upload. It is used to avoid making a request for
 * every single part, which would likely hit our rate limits.
 */
class BatchSigner {
  pendingRequests = [];
  #madeFirstRequest = false;

  constructor({ file, uploadRootPath }) {
    this.file = file;
    this.uploadRootPath = uploadRootPath;
  }

  signedUrlFor(partData) {
    const promise = new Promise((resolve, reject) => {
      this.pendingRequests.push({
        partData,
        resolve,
        reject,
      });
    });

    this.#scheduleSigning();
    return promise;
  }

  #scheduleSigning() {
    debounce(
      this,
      this.#signParts,
      this.#madeFirstRequest
        ? BATCH_SIGNER_REGULAR_DEBOUNCE
        : BATCH_SIGNER_INITIAL_DEBOUNCE
    );
  }

  async #signParts() {
    if (this.pendingRequests.length === 0) {
      return;
    }

    this.#madeFirstRequest = true;

    const requests = this.pendingRequests;
    this.pendingRequests = [];

    try {
      const result = await ajax(
        `${this.uploadRootPath}/batch-presign-multipart-parts.json`,
        {
          type: "POST",
          data: {
            part_numbers: requests.map(
              (request) => request.partData.partNumber
            ),
            unique_identifier: this.file.meta.unique_identifier,
          },
        }
      );
      requests.forEach(({ partData, resolve }) => {
        resolve(result.presigned_urls[partData.partNumber.toString()]);
      });
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error("[uppy] failed to get part signatures", err);
      requests.forEach(({ reject }) => reject(err));
      return;
    }
  }
}
