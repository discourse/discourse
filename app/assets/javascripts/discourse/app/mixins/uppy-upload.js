import Mixin from "@ember/object/mixin";
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
import { on } from "discourse-common/utils/decorators";
import { warn } from "@ember/debug";

export const HUGE_FILE_THRESHOLD_BYTES = 104_857_600; // 100MB

export default Mixin.create({
  uploading: false,
  uploadProgress: 0,
  _uppyInstance: null,
  autoStartUploads: true,
  id: null,

  // TODO (martin): this is only used in one place, consider just using
  // form data/meta instead uploadUrlParams: "&for_site_setting=true",
  uploadUrlParams: "",

  // TODO (martin): currently used for backups to turn on auto upload and PUT/XML requests
  // and for emojis to do sequential uploads, when we get to replacing those
  // with uppy make sure this is used when initializing uppy
  uploadOptions() {
    return {};
  },

  uploadDone() {
    warn("You should implement `uploadDone`", {
      id: "discourse.upload.missing-upload-done",
    });
  },

  validateUploadedFilesOptions() {
    return {};
  },

  @on("willDestroyElement")
  _destroy() {
    if (this.messageBus) {
      this.messageBus.unsubscribe(`/uploads/${this.type}`);
    }
    this.fileInputEl?.removeEventListener(
      "change",
      this.fileInputEventListener
    );
    this._uppyInstance?.close();
    this._uppyInstance = null;
  },

  @on("didInsertElement")
  _initialize() {
    this.setProperties({
      fileInputEl: this.element.querySelector(".hidden-upload-field"),
    });
    this.set("allowMultipleFiles", this.fileInputEl.multiple);

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
      meta: deepMerge({ upload_type: this.type }, this.data || {}),

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
        this.setProperties({ uploadProgress: 0, uploading: isValid });
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
      },
    });

    this._uppyInstance.use(DropTarget, { target: this.element });
    this._uppyInstance.use(UppyChecksum, { capabilities: this.capabilities });

    this._uppyInstance.on("progress", (progress) => {
      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      this.set("uploadProgress", progress);
    });

    this._uppyInstance.on("upload-success", (file, response) => {
      if (this.usingS3Uploads) {
        this.setProperties({ uploading: false, processing: true });
        this._completeExternalUpload(file)
          .then((completeResponse) => {
            this.uploadDone(completeResponse);
            this._reset();
          })
          .catch((errResponse) => {
            displayErrorForUpload(errResponse, this.siteSettings, file.name);
            this._reset();
          });
      } else {
        this.uploadDone(response.body);
        this._reset();
      }
    });

    this._uppyInstance.on("upload-error", (file, error, response) => {
      displayErrorForUpload(response, this.siteSettings, file.name);
      this._reset();
    });

    // hidden setting like enable_experimental_image_uploader
    if (this.siteSettings.enable_direct_s3_uploads) {
      this._useS3Uploads();
    } else {
      this._useXHRUploads();
    }
  },

  _useXHRUploads() {
    this._uppyInstance.use(XHRUpload, {
      endpoint: this._xhrUploadUrl(),
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

        return ajax(getUrl("/uploads/generate-presigned-put"), {
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
      getUrl(this.getWithDefault("uploadUrl", "/uploads")) +
      ".json?client_id=" +
      (this.messageBus && this.messageBus.clientId) +
      this.uploadUrlParams
    );
  },

  _bindFileInputChange() {
    this.fileInputEventListener = bindFileInputChangeListener(
      this.fileInputEl,
      (file) => {
        try {
          this._uppyInstance.addFile({
            source: `${this.id} file input`,
            name: file.name,
            type: file.type,
            data: file,
          });
        } catch (err) {
          warn(`error adding files to uppy: ${err}`, {
            id: "discourse.upload.uppy-add-files-error",
          });
        }
      }
    );
  },

  _completeExternalUpload(file) {
    return ajax(getUrl("/uploads/complete-external-upload"), {
      type: "POST",
      data: {
        unique_identifier: file.meta.uniqueUploadIdentifier,
      },
    });
  },

  _reset() {
    this._uppyInstance?.reset();
    this.setProperties({
      uploading: false,
      processing: false,
      uploadProgress: 0,
    });
  },
});
