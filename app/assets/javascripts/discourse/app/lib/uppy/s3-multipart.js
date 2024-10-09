import { setOwner } from "@ember/owner";
import { service } from "@ember/service";
import AwsS3Multipart from "@uppy/aws-s3-multipart";
import { Promise } from "rsvp";
import { ajax } from "discourse/lib/ajax";

const RETRY_DELAYS = [0, 1000, 3000, 5000];
const MB = 1024 * 1024;

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

    this.uppyInstance.use(AwsS3Multipart, {
      // controls how many simultaneous _chunks_ are uploaded, not files,
      // which in turn controls the minimum number of chunks presigned
      // in each batch (limit / 2)
      //
      // the default, and minimum, chunk size is 5mb. we can control the
      // chunk size via getChunkSize(file), so we may want to increase
      // the chunk size for larger files
      limit: 10,
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
      prepareUploadParts: this.#prepareUploadParts.bind(this),
      completeMultipartUpload: this.#completeMultipartUpload.bind(this),
      abortMultipartUpload: this.#abortMultipartUpload.bind(this),

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

  #prepareUploadParts(file, partData) {
    if (file.preparePartsRetryAttempts === undefined) {
      file.preparePartsRetryAttempts = 0;
    }
    return ajax(`${this.uploadRootPath}/batch-presign-multipart-parts.json`, {
      type: "POST",
      data: {
        part_numbers: partData.parts.map((part) => part.number),
        unique_identifier: file.meta.unique_identifier,
      },
    })
      .then((data) => {
        if (file.preparePartsRetryAttempts) {
          delete file.preparePartsRetryAttempts;
          this.uppyWrapper.debug.log(
            `[uppy] Retrying batch fetch for ${file.id} was successful, continuing.`
          );
        }
        return { presignedUrls: data.presigned_urls };
      })
      .catch((err) => {
        const status = err.jqXHR.status;

        // it is kind of ugly to have to track the retry attempts for
        // the file based on the retry delays, but uppy's `retryable`
        // function expects the rejected Promise data to be structured
        // _just so_, and provides no interface for us to tell how many
        // times the upload has been retried (which it tracks internally)
        //
        // if we exceed the attempts then there is no way that uppy will
        // retry the upload once again, so in that case the alert can
        // be safely shown to the user that their upload has failed.
        if (file.preparePartsRetryAttempts < RETRY_DELAYS.length) {
          file.preparePartsRetryAttempts += 1;
          const attemptsLeft =
            RETRY_DELAYS.length - file.preparePartsRetryAttempts + 1;
          this.uppyWrapper.debug.log(
            `[uppy] Fetching a batch of upload part URLs for ${file.id} failed with status ${status}, retrying ${attemptsLeft} more times...`
          );
          return Promise.reject({ source: { status } });
        } else {
          this.uppyWrapper.debug.log(
            `[uppy] Fetching a batch of upload part URLs for ${file.id} failed too many times, throwing error.`
          );
          // uppy is inconsistent, an error here does not fire the upload-error event
          this.handleUploadError(file, err);
        }
      });
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
