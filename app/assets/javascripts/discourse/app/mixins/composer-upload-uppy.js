import Mixin from "@ember/object/mixin";
import ExtendableUploader from "discourse/mixins/extendable-uploader";
import EmberObject from "@ember/object";
import UppyS3Multipart from "discourse/mixins/uppy-s3-multipart";
import { deepMerge } from "discourse-common/lib/object";
import UppyChecksum from "discourse/lib/uppy-checksum-plugin";
import Uppy from "@uppy/core";
import DropTarget from "@uppy/drop-target";
import XHRUpload from "@uppy/xhr-upload";
import { warn } from "@ember/debug";
import I18n from "I18n";
import getURL from "discourse-common/lib/get-url";
import { clipboardHelpers } from "discourse/lib/utilities";
import { bind, observes, on } from "discourse-common/utils/decorators";
import {
  bindFileInputChangeListener,
  displayErrorForUpload,
  getUploadMarkdown,
  validateUploadedFile,
} from "discourse/lib/uploads";
import { cacheShortUploadUrl } from "pretty-text/upload-short-url";
import bootbox from "bootbox";

// Note: This mixin is used _in addition_ to the ComposerUpload mixin
// on the composer-editor component. It overrides some, but not all,
// functions created by ComposerUpload. Eventually this will supplant
// ComposerUpload, but until then only the functions that need to be
// overridden to use uppy will be overridden, so as to not go out of
// sync with the main ComposerUpload functionality by copying unchanging
// functions.
//
// Some examples are uploadPlaceholder, the main properties e.g. uploadProgress,
// and the most important _bindUploadTarget which handles all the main upload
// functionality and event binding.
//
export default Mixin.create(ExtendableUploader, UppyS3Multipart, {
  uploadRootPath: "/uploads",
  uploadTargetBound: false,

  @bind
  _cancelSingleUpload(data) {
    this._uppyInstance.removeFile(data.fileId);
  },

  @observes("composerModel.uploadCancelled")
  _cancelUpload() {
    if (!this.get("composerModel.uploadCancelled")) {
      return;
    }
    this.set("composerModel.uploadCancelled", false);
    this.set("userCancelled", true);

    this._uppyInstance.cancelAll();
  },

  @on("willDestroyElement")
  _unbindUploadTarget() {
    if (!this.uploadTargetBound) {
      return;
    }

    this.fileInputEl?.removeEventListener(
      "change",
      this.fileInputEventListener
    );

    this.element.removeEventListener("paste", this.pasteEventListener);

    this.appEvents.off(`${this.eventPrefix}:add-files`, this._addFiles);
    this.appEvents.off(
      `${this.eventPrefix}:cancel-upload`,
      this._cancelSingleUpload
    );

    this._reset();

    if (this._uppyInstance) {
      this._uppyInstance.close();
      this._uppyInstance = null;
    }

    this.uploadTargetBound = false;
  },

  _abortAndReset() {
    this.appEvents.trigger(`${this.eventPrefix}:uploads-aborted`);
    this._reset();
    return false;
  },

  _bindUploadTarget() {
    this.set("inProgressUploads", []);
    this.placeholders = {};
    this._preProcessorStatus = {};
    this.fileInputEl = document.getElementById(this.fileUploadElementId);
    const isPrivateMessage = this.get("composerModel.privateMessage");

    this.appEvents.on(`${this.eventPrefix}:add-files`, this._addFiles);
    this.appEvents.on(
      `${this.eventPrefix}:cancel-upload`,
      this._cancelSingleUpload
    );

    this._unbindUploadTarget();
    this.fileInputEventListener = bindFileInputChangeListener(
      this.fileInputEl,
      this._addFiles
    );
    this.element.addEventListener("paste", this.pasteEventListener);

    this._uppyInstance = new Uppy({
      id: this.uppyId,
      autoProceed: true,

      // need to use upload_type because uppy overrides type with the
      // actual file type
      meta: deepMerge({ upload_type: this.uploadType }, this.data || {}),

      onBeforeFileAdded: (currentFile) => {
        const validationOpts = {
          user: this.currentUser,
          siteSettings: this.siteSettings,
          isPrivateMessage,
          allowStaffToUploadAnyFileInPm: this.siteSettings
            .allow_staff_to_upload_any_file_in_pm,
        };

        const isUploading = validateUploadedFile(currentFile, validationOpts);

        this.setProperties({
          uploadProgress: 0,
          isUploading,
          isCancellable: isUploading,
        });

        if (!isUploading) {
          this.appEvents.trigger(`${this.eventPrefix}:uploads-aborted`);
        }
        return isUploading;
      },

      onBeforeUpload: (files) => {
        const fileCount = Object.keys(files).length;
        const maxFiles = this.siteSettings.simultaneous_uploads;

        // Look for a matching file upload handler contributed from a plugin.
        // It is not ideal that this only works for single file uploads, but
        // at this time it is all we need. In future we may want to devise a
        // nicer way of doing this. Uppy plugins are out of the question because
        // there is no way to define which uploader plugin handles which file
        // extensions at this time.
        if (fileCount === 1) {
          const file = Object.values(files)[0];
          const matchingHandler = this._findMatchingUploadHandler(file.name);
          if (matchingHandler && !matchingHandler.method(file.data, this)) {
            return this._abortAndReset();
          }
        }

        // Limit the number of simultaneous uploads
        if (maxFiles > 0 && fileCount > maxFiles) {
          bootbox.alert(
            I18n.t("post.errors.too_many_dragged_and_dropped_files", {
              count: maxFiles,
            })
          );
          return this._abortAndReset();
        }
      },
    });

    if (this.siteSettings.enable_upload_debug_mode) {
      this._instrumentUploadTimings();
    }

    if (this.siteSettings.enable_direct_s3_uploads) {
      this._useS3MultipartUploads();
    } else {
      this._useXHRUploads();
    }

    // TODO (martin) develop upload handler guidance and an API to use; will
    // likely be using uppy plugins for this
    this._uppyInstance.on("file-added", (file) => {
      if (isPrivateMessage) {
        file.meta.for_private_message = true;
      }
    });

    this._uppyInstance.on("progress", (progress) => {
      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      this.set("uploadProgress", progress);
    });

    this._uppyInstance.on("file-removed", (file, reason) => {
      file.meta.cancelled = true;

      // we handle the cancel-all event specifically, so no need
      // to do anything here
      if (reason === "cancel-all") {
        return;
      }

      this._removeInProgressUpload(file.id);
      this._resetUpload(file, { removePlaceholder: true });
      if (this.inProgressUploads.length === 0) {
        this.set("userCancelled", true);
        this._uppyInstance.cancelAll();
      }
    });

    this._uppyInstance.on("upload-progress", (file, progress) => {
      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      const upload = this.inProgressUploads.find((upl) => upl.id === file.id);
      if (upload) {
        const percentage = Math.round(
          (progress.bytesUploaded / progress.bytesTotal) * 100
        );
        upload.set("progress", percentage);
      }
    });

    this._uppyInstance.on("upload", (data) => {
      this._addNeedProcessing(data.fileIDs.length);

      const files = data.fileIDs.map((fileId) =>
        this._uppyInstance.getFile(fileId)
      );

      this.setProperties({
        isProcessingUpload: true,
        isCancellable: false,
      });

      files.forEach((file) => {
        this.inProgressUploads.push(
          EmberObject.create({
            fileName: file.name,
            id: file.id,
            progress: 0,
          })
        );
        const placeholder = this._uploadPlaceholder(file);
        this.placeholders[file.id] = {
          uploadPlaceholder: placeholder,
        };
        this.appEvents.trigger(`${this.eventPrefix}:insert-text`, placeholder);
        this.appEvents.trigger(`${this.eventPrefix}:upload-started`, file.name);
      });
    });

    this._uppyInstance.on("upload-success", (file, response) => {
      this._removeInProgressUpload(file.id);
      let upload = response.body;
      const markdown = this.uploadMarkdownResolvers.reduce(
        (md, resolver) => resolver(upload) || md,
        getUploadMarkdown(upload)
      );

      cacheShortUploadUrl(upload.short_url, upload);

      this.appEvents.trigger(
        `${this.eventPrefix}:replace-text`,
        this.placeholders[file.id].uploadPlaceholder.trim(),
        markdown
      );

      this._resetUpload(file, { removePlaceholder: false });
      this.appEvents.trigger(
        `${this.eventPrefix}:upload-success`,
        file.name,
        upload
      );
    });

    this._uppyInstance.on("upload-error", this._handleUploadError);

    this._uppyInstance.on("complete", () => {
      this.appEvents.trigger(`${this.eventPrefix}:all-uploads-complete`);
      this._reset();
    });

    this._uppyInstance.on("cancel-all", () => {
      // uppyInstance.reset() also fires cancel-all, so we want to
      // only do the manual cancelling work if the user clicked cancel
      if (this.userCancelled) {
        Object.values(this.placeholders).forEach((data) => {
          this.appEvents.trigger(
            `${this.eventPrefix}:replace-text`,
            data.uploadPlaceholder,
            ""
          );
        });

        this.set("userCancelled", false);
        this._reset();

        this.appEvents.trigger(`${this.eventPrefix}:uploads-cancelled`);
      }
    });

    this._setupPreProcessors();
    this._setupUIPlugins();

    this.uploadTargetBound = true;
  },

  @bind
  _handleUploadError(file, error, response) {
    this._removeInProgressUpload(file.id);
    this._resetUpload(file, { removePlaceholder: true });

    file.meta.error = error;

    if (!this.userCancelled) {
      displayErrorForUpload(response || error, this.siteSettings, file.name);
      this.appEvents.trigger(`${this.eventPrefix}:upload-error`, file);
    }

    if (this.inProgressUploads.length === 0) {
      this._reset();
    }
  },

  _removeInProgressUpload(fileId) {
    this.set(
      "inProgressUploads",
      this.inProgressUploads.filter((upl) => upl.id !== fileId)
    );
  },

  _setupPreProcessors() {
    const checksumPreProcessor = {
      pluginClass: UppyChecksum,
      optionsResolverFn: ({ capabilities }) => {
        return {
          capabilities,
        };
      },
    };

    // It is important that the UppyChecksum preprocessor is the last one to
    // be added; the preprocessors are run in order and since other preprocessors
    // may modify the file (e.g. the UppyMediaOptimization one), we need to
    // checksum once we are sure the file data has "settled".
    [this.uploadPreProcessors, checksumPreProcessor]
      .flat()
      .forEach(({ pluginClass, optionsResolverFn }) => {
        this._useUploadPlugin(
          pluginClass,
          optionsResolverFn({
            composerModel: this.composerModel,
            composerElement: this.composerElement,
            capabilities: this.capabilities,
            isMobileDevice: this.site.isMobileDevice,
          })
        );
      });

    this._onPreProcessProgress((file) => {
      let placeholderData = this.placeholders[file.id];
      placeholderData.processingPlaceholder = `[${I18n.t(
        "processing_filename",
        {
          filename: file.name,
        }
      )}]()\n`;

      this.appEvents.trigger(
        `${this.eventPrefix}:replace-text`,
        placeholderData.uploadPlaceholder,
        placeholderData.processingPlaceholder
      );
    });

    this._onPreProcessComplete(
      (file) => {
        let placeholderData = this.placeholders[file.id];
        this.appEvents.trigger(
          `${this.eventPrefix}:replace-text`,
          placeholderData.processingPlaceholder,
          placeholderData.uploadPlaceholder
        );
      },
      () => {
        this.setProperties({
          isProcessingUpload: false,
          isCancellable: true,
        });
        this.appEvents.trigger(
          `${this.eventPrefix}:uploads-preprocessing-complete`
        );
      }
    );
  },

  _setupUIPlugins() {
    this._uppyInstance.use(DropTarget, { target: this.element });
  },

  _uploadFilenamePlaceholder(file) {
    const filename = this._filenamePlaceholder(file);

    // when adding two separate files with the same filename search for matching
    // placeholder already existing in the editor ie [Uploading: test.png...]
    // and add order nr to the next one: [Uploading: test.png(1)...]
    const escapedFilename = filename.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const regexString = `\\[${I18n.t("uploading_filename", {
      filename: escapedFilename + "(?:\\()?([0-9])?(?:\\))?",
    })}\\]\\(\\)`;
    const globalRegex = new RegExp(regexString, "g");
    const matchingPlaceholder = this.get(
      `composerModel.${this.composerModelContentKey}`
    ).match(globalRegex);
    if (matchingPlaceholder) {
      // get last matching placeholder and its consecutive nr in regex
      // capturing group and apply +1 to the placeholder
      const lastMatch = matchingPlaceholder[matchingPlaceholder.length - 1];
      const regex = new RegExp(regexString);
      const orderNr = regex.exec(lastMatch)[1]
        ? parseInt(regex.exec(lastMatch)[1], 10) + 1
        : 1;
      return `${filename}(${orderNr})`;
    }

    return filename;
  },

  _uploadPlaceholder(file) {
    const clipboard = I18n.t("clipboard");
    const uploadFilenamePlaceholder = this._uploadFilenamePlaceholder(file);
    const filename = uploadFilenamePlaceholder
      ? uploadFilenamePlaceholder
      : clipboard;

    let placeholder = `[${I18n.t("uploading_filename", { filename })}]()\n`;
    if (!this._cursorIsOnEmptyLine()) {
      placeholder = `\n${placeholder}`;
    }

    return placeholder;
  },

  _useXHRUploads() {
    this._uppyInstance.use(XHRUpload, {
      endpoint: getURL(`/uploads.json?client_id=${this.messageBus.clientId}`),
      headers: {
        "X-CSRF-Token": this.session.csrfToken,
      },
    });
  },

  _reset() {
    this._uppyInstance?.reset();
    this.setProperties({
      uploadProgress: 0,
      isUploading: false,
      isProcessingUpload: false,
      isCancellable: false,
    });
    this._resetPreProcessors();
    this.fileInputEl.value = "";
  },

  _resetUpload(file, opts) {
    if (opts.removePlaceholder) {
      this.appEvents.trigger(
        `${this.eventPrefix}:replace-text`,
        this.placeholders[file.id].uploadPlaceholder,
        ""
      );
    }
  },

  @bind
  pasteEventListener(event) {
    if (
      document.activeElement !== document.querySelector(this.editorInputClass)
    ) {
      return;
    }

    const { canUpload } = clipboardHelpers(event, {
      siteSettings: this.siteSettings,
      canUpload: true,
    });

    if (!canUpload) {
      return;
    }

    if (event && event.clipboardData && event.clipboardData.files) {
      this._addFiles([...event.clipboardData.files], { pasted: true });
    }
  },

  @bind
  _addFiles(files, opts = {}) {
    files = Array.isArray(files) ? files : [files];
    try {
      this._uppyInstance.addFiles(
        files.map((file) => {
          return {
            source: this.uppyId,
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

  showUploadSelector(toolbarEvent) {
    this.send("showUploadSelector", toolbarEvent);
  },
});
