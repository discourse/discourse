import { tracked } from "@glimmer/tracking";
import { warn } from "@ember/debug";
import EmberObject from "@ember/object";
import { getOwner, setOwner } from "@ember/owner";
import { run } from "@ember/runloop";
import { service } from "@ember/service";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import AwsS3 from "@uppy/aws-s3";
import Uppy from "@uppy/core";
import DropTarget from "@uppy/drop-target";
import XHRUpload from "@uppy/xhr-upload";
import { ajax, updateCsrfToken } from "discourse/lib/ajax";
import {
  bindFileInputChangeListener,
  displayErrorForUpload,
  validateUploadedFile,
} from "discourse/lib/uploads";
import UppyS3Multipart from "discourse/lib/uppy/s3-multipart";
import UppyWrapper from "discourse/lib/uppy/wrapper";
import UppyChecksum from "discourse/lib/uppy-checksum-plugin";
import UppyChunkedUploader from "discourse/lib/uppy-chunked-uploader-plugin";
import getUrl from "discourse-common/lib/get-url";
import { deepMerge } from "discourse-common/lib/object";
import { bind } from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";

export const HUGE_FILE_THRESHOLD_BYTES = 104_857_600; // 100MB

const DEFAULT_CONFIG = {
  uploadDone: null,
  uploadError: null,
  autoStartUploads: true,
  uploadUrl: null,
  uploadRootPath: "/uploads",
  validateUploadedFilesOptions: {},
  additionalParams: {},
  maxFiles: null,

  /**
   * Overridable for custom file validations, executed before uploading.
   *
   * @param {object} file
   *
   * @returns {boolean}
   */
  isUploadedFileAllowed: () => true,

  /** set file data on a per-file basis */
  perFileData: null,

  uploadDropTargetOptions: null,
  preventDirectS3Uploads: false,
  useChunkedUploads: false,
  useMultipartUploadsIfAvailable: false,
  uppyReady: null,
  onProgressUploadsChanged: null,
  type: null,
};

// Merges incoming config with defaults, without actually evaluating
// any getters on the incoming config.
function lazyMergeConfig(config) {
  const mergedConfig = {};

  const incomingDescriptors = Object.getOwnPropertyDescriptors(config);
  const defaultDescriptors = Object.getOwnPropertyDescriptors(DEFAULT_CONFIG);

  Object.defineProperties(mergedConfig, {
    ...defaultDescriptors,
    ...incomingDescriptors,
  });

  return mergedConfig;
}

const REQUIRED_CONFIG_KEYS = ["id", "uploadDone", "type"];
function validateConfig(config) {
  for (const key of REQUIRED_CONFIG_KEYS) {
    if (!config[key]) {
      throw new Error(`Missing required UppyUpload config: ${key}`);
    }
  }
}

export default class UppyUpload {
  @service dialog;
  @service messageBus;
  @service appEvents;
  @service siteSettings;
  @service capabilities;
  @service session;

  @tracked uploading = false;
  @tracked processing = false;
  @tracked uploadProgress = 0;
  @tracked allowMultipleFiles;
  @tracked filesAwaitingUpload = false;
  @tracked cancellable = false;

  inProgressUploads = new TrackedArray();

  uppyWrapper;

  #fileInputEventListener;
  #usingS3Uploads;

  _fileInputEl;

  constructor(owner, config) {
    setOwner(this, owner);
    this.uppyWrapper = new UppyWrapper(owner);
    this.config = lazyMergeConfig(config);
    validateConfig(this.config);
  }

  teardown() {
    this.messageBus.unsubscribe(`/uploads/${this.config.type}`);

    this._fileInputEl?.removeEventListener(
      "change",
      this.#fileInputEventListener
    );
    this.appEvents.off(
      `upload-mixin:${this.config.id}:add-files`,
      this.addFiles
    );
    this.appEvents.off(
      `upload-mixin:${this.config.id}:cancel-upload`,
      this.cancelSingleUpload
    );
    this.uppyWrapper.uppyInstance?.close();
  }

  @bind
  setup(fileInputEl) {
    if (fileInputEl) {
      this._fileInputEl = fileInputEl;
      this.allowMultipleFiles = this._fileInputEl.multiple;
      this.#bindFileInputChange();
    }

    this.uppyWrapper.uppyInstance = new Uppy({
      id: this.config.id,
      autoProceed: this.config.autoStartUploads,

      // need to use upload_type because uppy overrides type with the
      // actual file type
      meta: deepMerge(
        { upload_type: this.config.type },
        this.#resolvedAdditionalParams
      ),

      onBeforeFileAdded: (currentFile) => {
        const validationOpts = deepMerge(
          {
            bypassNewUserRestriction: true,
            user: this.currentUser,
            siteSettings: this.siteSettings,
            validateSize: true,
          },
          this.config.validateUploadedFilesOptions
        );
        const isValid =
          validateUploadedFile(currentFile, validationOpts) &&
          this.config.isUploadedFileAllowed(currentFile);
        Object.assign(this, {
          uploadProgress: 0,
          uploading: isValid && this.config.autoStartUploads,
          filesAwaitingUpload: !this.config.autoStartUploads,
          cancellable: isValid && this.config.autoStartUploads,
        });
        return isValid;
      },

      onBeforeUpload: (files) => {
        let tooMany = false;
        const fileCount = Object.keys(files).length;
        const maxFiles =
          this.config.maxFiles || this.siteSettings.simultaneous_uploads;

        if (this.allowMultipleFiles) {
          tooMany = maxFiles > 0 && fileCount > maxFiles;
        } else {
          tooMany = fileCount > 1;
        }

        if (tooMany) {
          this.dialog.alert(
            i18n("post.errors.too_many_dragged_and_dropped_files", {
              count: this.allowMultipleFiles ? maxFiles : 1,
            })
          );
          this.#reset();
          return false;
        }

        Object.values(files).forEach((file) => {
          deepMerge(file.meta, this.config.perFileData?.(file));
        });
      },
    });

    const resolvedDropTargetOptions = this.#resolvedDropTargetOptions;
    if (resolvedDropTargetOptions) {
      // DropTarget is a UI plugin, only preprocessors must call _useUploadPlugin
      this.uppyWrapper.uppyInstance.use(DropTarget, resolvedDropTargetOptions);
    }

    this.uppyWrapper.uppyInstance.on("progress", (progress) => {
      this.uploadProgress = progress;
    });

    this.uppyWrapper.uppyInstance.on("upload", (uploadId, files) => {
      this.uppyWrapper.addNeedProcessing(files.length);
      this.processing = true;
      this.cancellable = false;
      files.forEach((file) => {
        this.inProgressUploads.push(
          EmberObject.create({
            fileName: file.name,
            id: file.id,
            progress: 0,
            extension: file.extension,
            processing: false,
          })
        );
        this.#triggerInProgressUploadsEvent();
      });
    });

    this.uppyWrapper.uppyInstance.on("upload-progress", (file, progress) => {
      run(() => {
        const upload = this.inProgressUploads.find((upl) => upl.id === file.id);
        if (upload) {
          const percentage = Math.round(
            (progress.bytesUploaded / progress.bytesTotal) * 100
          );
          upload.set("progress", percentage);
        }
      });
    });

    this.uppyWrapper.uppyInstance.on("upload-success", (file, response) => {
      if (this.#usingS3Uploads) {
        Object.assign(this, { uploading: false, processing: true });
        this.#completeExternalUpload(file)
          .then((completeResponse) => {
            this.#removeInProgressUpload(file.id);
            this.appEvents.trigger(
              `upload-mixin:${this.config.id}:upload-success`,
              file.name,
              completeResponse
            );
            this.config.uploadDone(
              deepMerge(completeResponse, { file_name: file.name })
            );

            this.#triggerInProgressUploadsEvent();
            if (this.inProgressUploads.length === 0) {
              this.#allUploadsComplete();
            }
          })
          .catch((errResponse) => {
            displayErrorForUpload(errResponse, this.siteSettings, file.name);
            this.#triggerInProgressUploadsEvent();
          });
      } else {
        this.#removeInProgressUpload(file.id);
        const upload = response?.body || {};
        this.appEvents.trigger(
          `upload-mixin:${this.config.id}:upload-success`,
          file.name,
          upload
        );
        this.config.uploadDone(deepMerge(upload, { file_name: file.name }));

        this.#triggerInProgressUploadsEvent();
        if (this.inProgressUploads.length === 0) {
          this.#allUploadsComplete();
        }
      }
    });

    this.uppyWrapper.uppyInstance.on(
      "upload-error",
      (file, error, response) => {
        if (response.aborted) {
          return; // User cancelled the upload
        }
        this.#removeInProgressUpload(file.id);
        displayErrorForUpload(response || error, this.siteSettings, file.name);
        this.#reset();
      }
    );

    this.uppyWrapper.uppyInstance.on("file-removed", (file, reason) => {
      run(() => {
        // we handle the cancel-all event specifically, so no need
        // to do anything here. this event is also fired when some files
        // are handled by an upload handler
        if (reason === "cancel-all") {
          return;
        }
        this.appEvents.trigger(
          `upload-mixin:${this.config.id}:upload-cancelled`,
          file.id
        );
      });
    });

    if (this.siteSettings.enable_upload_debug_mode) {
      this.uppyWrapper.debug.instrumentUploadTimings(
        this.uppyWrapper.uppyInstance
      );
    }

    // TODO (martin) preventDirectS3Uploads is necessary because some of
    // the current upload mixin components, for example the emoji uploader,
    // send the upload to custom endpoints that do fancy things in the rails
    // controller with the upload or create additional data or records. we
    // need a nice way to do this on complete-external-upload before we can
    // allow these other uploaders to go direct to S3.
    if (
      this.siteSettings.enable_direct_s3_uploads &&
      !this.config.preventDirectS3Uploads &&
      !this.config.useChunkedUploads
    ) {
      if (this.config.useMultipartUploadsIfAvailable) {
        new UppyS3Multipart(getOwner(this), {
          uploadRootPath: this.config.uploadRootPath,
          uppyWrapper: this.uppyWrapper,
          errorHandler: this.config.uploadError,
        }).apply(this.uppyWrapper.uppyInstance);
      } else {
        this.#useS3Uploads();
      }
    } else {
      if (this.config.useChunkedUploads) {
        this.#useChunkedUploads();
      } else {
        this.#useXHRUploads();
      }
    }

    this.uppyWrapper.uppyInstance.on("cancel-all", () => {
      this.appEvents.trigger(
        `upload-mixin:${this.config.id}:uploads-cancelled`
      );

      if (this.inProgressUploads.length) {
        this.inProgressUploads.length = 0; // Clear array in-place
        this.#triggerInProgressUploadsEvent();
      }
    });

    this.appEvents.on(
      `upload-mixin:${this.config.id}:add-files`,
      this.addFiles
    );
    this.appEvents.on(
      `upload-mixin:${this.config.id}:cancel-upload`,
      this.cancelSingleUpload
    );
    this.config.uppyReady?.();

    // It is important that the UppyChecksum preprocessor is the last one to
    // be added; the preprocessors are run in order and since other preprocessors
    // may modify the file (e.g. the UppyMediaOptimization one), we need to
    // checksum once we are sure the file data has "settled".
    this.uppyWrapper.useUploadPlugin(UppyChecksum, {
      capabilities: this.capabilities,
    });
  }

  @bind
  openPicker() {
    this._fileInputEl.click();
  }

  #triggerInProgressUploadsEvent() {
    this.config.onProgressUploadsChanged?.(this.inProgressUploads);
    this.appEvents.trigger(
      `upload-mixin:${this.config.id}:in-progress-uploads`,
      this.inProgressUploads
    );
  }

  /**
   * If auto upload is disabled, use this function to start the upload process.
   */
  startUpload() {
    if (!this.filesAwaitingUpload) {
      return;
    }
    if (!this.uppyWrapper.uppyInstance?.getFiles().length) {
      return;
    }
    this.uploading = true;
    return this.uppyWrapper.uppyInstance?.upload();
  }

  #useXHRUploads() {
    this.uppyWrapper.uppyInstance.use(XHRUpload, {
      endpoint: this.#xhrUploadUrl(),
      shouldRetry: () => false,
      headers: () => ({
        "X-CSRF-Token": this.session.csrfToken,
      }),
    });
  }

  #useChunkedUploads() {
    this.uppyWrapper.uppyInstance.use(UppyChunkedUploader, {
      url: this.#xhrUploadUrl(),
      headers: {
        "X-CSRF-Token": this.session.csrfToken,
      },
    });
  }

  #useS3Uploads() {
    this.#usingS3Uploads = true;
    this.uppyWrapper.uppyInstance.use(AwsS3, {
      shouldUseMultipart: false,
      getUploadParameters: (file) => {
        const data = {
          file_name: file.name,
          file_size: file.size,
          type: this.config.type,
        };

        // the sha1 checksum is set by the UppyChecksum plugin, except
        // for in cases where the browser does not support the required
        // crypto mechanisms or an error occurs. it is an additional layer
        // of security, and not required.
        if (file.meta.sha1_checksum) {
          data.metadata = { "sha1-checksum": file.meta.sha1_checksum };
        }

        return ajax(`${this.config.uploadRootPath}/generate-presigned-put`, {
          type: "POST",
          data,
        })
          .then((response) => {
            this.uppyWrapper.uppyInstance.setFileMeta(file.id, {
              uniqueUploadIdentifier: response.unique_identifier,
            });

            return {
              method: "put",
              url: response.url,
              headers: {
                ...response.signed_headers,
                "Content-Type": file.type,
              },
            };
          })
          .catch((errResponse) => {
            displayErrorForUpload(errResponse, this.siteSettings, file.name);
            this.#reset();
          });
      },
    });
  }

  #xhrUploadUrl() {
    const uploadUrl = this.config.uploadUrl || this.config.uploadRootPath;
    return getUrl(uploadUrl) + ".json?client_id=" + this.messageBus.clientId;
  }

  #bindFileInputChange() {
    this.#fileInputEventListener = bindFileInputChangeListener(
      this._fileInputEl,
      this.addFiles
    );
  }

  @bind
  cancelSingleUpload(data) {
    this.uppyWrapper.uppyInstance.removeFile(data.fileId);
    this.#removeInProgressUpload(data.fileId);
  }

  @bind
  cancelAllUploads() {
    this.uppyWrapper.uppyInstance?.cancelAll();
    this.inProgressUploads.length = 0;
    this.#triggerInProgressUploadsEvent();
  }

  @bind
  async addFiles(files, opts = {}) {
    if (!this.session.csrfToken) {
      await updateCsrfToken();
    }

    files = Array.isArray(files) ? files : [files];

    try {
      this.uppyWrapper.uppyInstance.addFiles(
        files.map((file) => {
          return {
            source: this.config.id,
            name: file.name,
            type: file.type,
            data: file,
            meta: { pasted: opts.pasted },
          };
        })
      );
    } catch (err) {
      warn(`error adding files to uppy: ${err}`, {
        id: "discourse.upload.uppy-add-files-error",
      });
    }
  }

  #completeExternalUpload(file) {
    return ajax(`${this.config.uploadRootPath}/complete-external-upload`, {
      type: "POST",
      data: deepMerge(
        { unique_identifier: file.meta.uniqueUploadIdentifier },
        this.#resolvedAdditionalParams
      ),
    });
  }

  get #resolvedAdditionalParams() {
    if (typeof this.config.additionalParams === "function") {
      return this.config.additionalParams();
    } else {
      return this.config.additionalParams;
    }
  }

  get #resolvedDropTargetOptions() {
    if (typeof this.config.uploadDropTargetOptions === "function") {
      return this.config.uploadDropTargetOptions();
    } else {
      return this.config.uploadDropTargetOptions;
    }
  }

  #reset() {
    this.uppyWrapper.uppyInstance?.cancelAll();
    Object.assign(this, {
      uploading: false,
      processing: false,
      cancellable: false,
      uploadProgress: 0,
      filesAwaitingUpload: false,
    });
    if (this._fileInputEl) {
      this._fileInputEl.value = "";
    }
  }

  #removeInProgressUpload(fileId) {
    const index = this.inProgressUploads.findIndex((upl) => upl.id === fileId);
    if (index === -1) {
      return;
    }
    this.inProgressUploads.splice(index, 1);
    this.#triggerInProgressUploadsEvent();
  }

  #allUploadsComplete() {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    this.appEvents.trigger(
      `upload-mixin:${this.config.id}:all-uploads-complete`
    );
    this.#reset();
  }
}
