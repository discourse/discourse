import Mixin from "@ember/object/mixin";
import { or } from "@ember/object/computed";
import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import {
  bindFileInputChangeListener,
  displayErrorForUpload,
  validateUploadedFile,
} from "discourse/lib/uploads";
import { deepMerge } from "discourse-common/lib/object";
import getUrl from "discourse-common/lib/get-url";
import I18n from "I18n";
import Uppy from "@uppy/core";
import DropTarget from "@uppy/drop-target";
import XHRUpload from "@uppy/xhr-upload";
import AwsS3 from "@uppy/aws-s3";
import UppyChecksum from "discourse/lib/uppy-checksum-plugin";
import UppyS3Multipart from "discourse/mixins/uppy-s3-multipart";
import UppyChunkedUploader from "discourse/lib/uppy-chunked-uploader-plugin";
import { bind, on } from "discourse-common/utils/decorators";
import { warn } from "@ember/debug";
import bootbox from "bootbox";

export const HUGE_FILE_THRESHOLD_BYTES = 104_857_600; // 100MB

export default Mixin.create(UppyS3Multipart, {
  uploading: false,
  uploadProgress: 0,
  _uppyInstance: null,
  autoStartUploads: true,
  inProgressUploads: null,
  id: null,
  uploadRootPath: "/uploads",
  fileInputSelector: ".hidden-upload-field",

  uploadDone() {
    warn("You should implement `uploadDone`", {
      id: "discourse.upload.missing-upload-done",
    });
  },

  validateUploadedFilesOptions() {
    return {};
  },

  uploadingOrProcessing: or("uploading", "processing"),

  @on("willDestroyElement")
  _destroy() {
    if (this.messageBus) {
      this.messageBus.unsubscribe(`/uploads/${this.type}`);
    }
    this.fileInputEl?.removeEventListener(
      "change",
      this.fileInputEventListener
    );
    this.appEvents.off(`upload-mixin:${this.id}:add-files`, this._addFiles);
    this._uppyInstance?.close();
    this._uppyInstance = null;
  },

  @on("didInsertElement")
  _initialize() {
    this.setProperties({
      fileInputEl: this.element.querySelector(this.fileInputSelector),
    });
    this.set("allowMultipleFiles", this.fileInputEl.multiple);
    this.set("inProgressUploads", []);

    this._bindFileInputChange();

    if (!this.id) {
      warn(
        "uppy needs a unique id, pass one in to the component implementing this mixin",
        {
          id: "discourse.upload.missing-id",
        }
      );
    }

    this._uppyInstance = new Uppy({
      id: this.id,
      autoProceed: this.autoStartUploads,

      // need to use upload_type because uppy overrides type with the
      // actual file type
      meta: deepMerge(
        { upload_type: this.type },
        this.additionalParams || {},
        this.data || {}
      ),

      onBeforeFileAdded: (currentFile) => {
        const validationOpts = deepMerge(
          {
            bypassNewUserRestriction: true,
            user: this.currentUser,
            siteSettings: this.siteSettings,
            validateSize: true,
          },
          this.validateUploadedFilesOptions()
        );
        const isValid = validateUploadedFile(currentFile, validationOpts);
        this.setProperties({
          uploadProgress: 0,
          uploading: isValid && this.autoStartUploads,
          filesAwaitingUpload: !this.autoStartUploads,
        });
        return isValid;
      },

      onBeforeUpload: (files) => {
        let tooMany = false;
        const fileCount = Object.keys(files).length;
        const maxFiles = this.getWithDefault(
          "maxFiles",
          this.siteSettings.simultaneous_uploads
        );

        if (this.allowMultipleFiles) {
          tooMany = maxFiles > 0 && fileCount > maxFiles;
        } else {
          tooMany = fileCount > 1;
        }

        if (tooMany) {
          bootbox.alert(
            I18n.t("post.errors.too_many_dragged_and_dropped_files", {
              count: this.allowMultipleFiles ? maxFiles : 1,
            })
          );
          this._reset();
          return false;
        }

        if (this._perFileData) {
          Object.values(files).forEach((file) => {
            deepMerge(file.meta, this._perFileData());
          });
        }
      },
    });

    this._uppyInstance.use(DropTarget, this._uploadDropTargetOptions());
    this._uppyInstance.use(UppyChecksum, { capabilities: this.capabilities });

    this._uppyInstance.on("progress", (progress) => {
      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      this.set("uploadProgress", progress);
    });

    this._uppyInstance.on("upload", (data) => {
      const files = data.fileIDs.map((fileId) =>
        this._uppyInstance.getFile(fileId)
      );
      files.forEach((file) => {
        this.inProgressUploads.push(
          EmberObject.create({
            fileName: file.name,
            id: file.id,
            progress: 0,
          })
        );
      });
    });

    this._uppyInstance.on("upload-success", (file, response) => {
      this._removeInProgressUpload(file.id);

      if (this.usingS3Uploads) {
        this.setProperties({ uploading: false, processing: true });
        this._completeExternalUpload(file)
          .then((completeResponse) => {
            this.uploadDone(
              deepMerge(completeResponse, { file_name: file.name })
            );

            if (this.inProgressUploads.length === 0) {
              this._reset();
            }
          })
          .catch((errResponse) => {
            displayErrorForUpload(errResponse, this.siteSettings, file.name);
            if (this.inProgressUploads.length === 0) {
              this._reset();
            }
          });
      } else {
        this.uploadDone(
          deepMerge(response?.body || {}, { file_name: file.name })
        );
        if (this.inProgressUploads.length === 0) {
          this._reset();
        }
      }
    });

    this._uppyInstance.on("upload-error", (file, error, response) => {
      this._removeInProgressUpload(file.id);
      displayErrorForUpload(response || error, this.siteSettings, file.name);
      this._reset();
    });

    // TODO (martin) preventDirectS3Uploads is necessary because some of
    // the current upload mixin components, for example the emoji uploader,
    // send the upload to custom endpoints that do fancy things in the rails
    // controller with the upload or create additional data or records. we
    // need a nice way to do this on complete-external-upload before we can
    // allow these other uploaders to go direct to S3.
    if (
      this.siteSettings.enable_direct_s3_uploads &&
      !this.preventDirectS3Uploads &&
      !this.useChunkedUploads
    ) {
      if (this.useMultipartUploadsIfAvailable) {
        this._useS3MultipartUploads();
      } else {
        this._useS3Uploads();
      }
    } else {
      if (this.useChunkedUploads) {
        this._useChunkedUploads();
      } else {
        this._useXHRUploads();
      }
    }

    this.appEvents.on(`upload-mixin:${this.id}:add-files`, this._addFiles);
    this._uppyReady();
  },

  // This should be overridden in a child component if you need to
  // hook into uppy events and be sure that everything is already
  // set up for _uppyInstance.
  _uppyReady() {},

  _startUpload() {
    if (!this.filesAwaitingUpload) {
      return;
    }
    if (!this._uppyInstance?.getFiles().length) {
      return;
    }
    this.set("uploading", true);
    return this._uppyInstance?.upload();
  },

  _useXHRUploads() {
    this._uppyInstance.use(XHRUpload, {
      endpoint: this._xhrUploadUrl(),
      headers: {
        "X-CSRF-Token": this.session.csrfToken,
      },
    });
  },

  _useChunkedUploads() {
    this.set("usingChunkedUploads", true);
    this._uppyInstance.use(UppyChunkedUploader, {
      url: this._xhrUploadUrl(),
      headers: {
        "X-CSRF-Token": this.session.csrfToken,
      },
    });
  },

  _useS3Uploads() {
    this.set("usingS3Uploads", true);
    this._uppyInstance.use(AwsS3, {
      getUploadParameters: (file) => {
        const data = {
          file_name: file.name,
          file_size: file.size,
          type: this.type,
        };

        // the sha1 checksum is set by the UppyChecksum plugin, except
        // for in cases where the browser does not support the required
        // crypto mechanisms or an error occurs. it is an additional layer
        // of security, and not required.
        if (file.meta.sha1_checksum) {
          data.metadata = { "sha1-checksum": file.meta.sha1_checksum };
        }

        return ajax(getUrl(`${this.uploadRootPath}/generate-presigned-put`), {
          type: "POST",
          data,
        })
          .then((response) => {
            this._uppyInstance.setFileMeta(file.id, {
              uniqueUploadIdentifier: response.unique_identifier,
            });

            return {
              method: "put",
              url: response.url,
              headers: {
                "Content-Type": file.type,
              },
            };
          })
          .catch((errResponse) => {
            displayErrorForUpload(errResponse, this.siteSettings, file.name);
            this._reset();
          });
      },
    });
  },

  _xhrUploadUrl() {
    return (
      getUrl(this.getWithDefault("uploadUrl", this.uploadRootPath)) +
      ".json?client_id=" +
      this.messageBus?.clientId
    );
  },

  _bindFileInputChange() {
    this.fileInputEventListener = bindFileInputChangeListener(
      this.fileInputEl,
      this._addFiles
    );
  },

  @bind
  _addFiles(files, opts = {}) {
    files = Array.isArray(files) ? files : [files];
    try {
      this._uppyInstance.addFiles(
        files.map((file) => {
          return {
            source: this.id,
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
  },

  _completeExternalUpload(file) {
    return ajax(getUrl(`${this.uploadRootPath}/complete-external-upload`), {
      type: "POST",
      data: deepMerge(
        { unique_identifier: file.meta.uniqueUploadIdentifier },
        this.additionalParams || {}
      ),
    });
  },

  _reset() {
    this._uppyInstance?.reset();
    this.setProperties({
      uploading: false,
      processing: false,
      uploadProgress: 0,
      filesAwaitingUpload: false,
    });
    this.fileInputEl.value = "";
  },

  _removeInProgressUpload(fileId) {
    this.set(
      "inProgressUploads",
      this.inProgressUploads.filter((upl) => upl.id !== fileId)
    );
  },

  // target must be provided as a DOM element, however the
  // onDragOver and onDragLeave callbacks can also be provided.
  // it is advisable to debounce/add a setTimeout timer when
  // doing anything in these callbacks to avoid jumping. uppy
  // also adds a .uppy-is-drag-over class to the target element by
  // default onDragOver and removes it onDragLeave
  _uploadDropTargetOptions() {
    return { target: this.element };
  },
});
