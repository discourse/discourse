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
import { run } from "@ember/runloop";

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

    this.editorEl?.removeEventListener("paste", this.pasteEventListener);

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
    this.editorEl = this.element.querySelector(this.editorClass);
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
    this.editorEl.addEventListener("paste", this.pasteEventListener);

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
        const maxFiles = this.siteSettings.simultaneous_uploads;

        // Look for a matching file upload handler contributed from a plugin.
        // In future we may want to devise a nicer way of doing this.
        // Uppy plugins are out of the question because there is no way to
        // define which uploader plugin handles which file extensions at this time.
        const unhandledFiles = {};
        const handlerBuckets = {};

        for (const [fileId, file] of Object.entries(files)) {
          const matchingHandler = this._findMatchingUploadHandler(file.name);
          if (matchingHandler) {
            // the function signature will be converted to a string for the
            // object key, so we can send multiple files at once to each handler
            if (handlerBuckets[matchingHandler.method]) {
              handlerBuckets[matchingHandler.method].files.push(file);
            } else {
              handlerBuckets[matchingHandler.method] = {
                fn: matchingHandler.method,
                // file.data is the native File object, which is all the plugins
                // should need, not the uppy wrapper
                files: [file.data],
              };
            }
          } else {
            unhandledFiles[fileId] = { ...files[fileId] };
          }
        }

        // Send the collected array of files to each matching handler,
        // rather than the old jQuery file uploader method of sending
        // a single file at a time through to the handler.
        for (const bucket of Object.values(handlerBuckets)) {
          if (!bucket.fn(bucket.files, this)) {
            return this._abortAndReset();
          }
        }

        // Limit the number of simultaneous uploads, for files which have
        // _not_ been handled by an upload handler.
        const fileCount = Object.keys(unhandledFiles).length;
        if (maxFiles > 0 && fileCount > maxFiles) {
          bootbox.alert(
            I18n.t("post.errors.too_many_dragged_and_dropped_files", {
              count: maxFiles,
            })
          );
          return this._abortAndReset();
        }

        // uppy uses this new object to track progress of remaining files
        return unhandledFiles;
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

    this._uppyInstance.on("file-added", (file) => {
      run(() => {
        if (isPrivateMessage) {
          file.meta.for_private_message = true;
        }
      });
    });

    this._uppyInstance.on("progress", (progress) => {
      run(() => {
        if (this.isDestroying || this.isDestroyed) {
          return;
        }

        this.set("uploadProgress", progress);
      });
    });

    this._uppyInstance.on("file-removed", (file, reason) => {
      run(() => {
        // we handle the cancel-all event specifically, so no need
        // to do anything here. this event is also fired when some files
        // are handled by an upload handler
        if (reason === "cancel-all") {
          return;
        }

        file.meta.cancelled = true;
        this._removeInProgressUpload(file.id);
        this._resetUpload(file, { removePlaceholder: true });
        if (this.inProgressUploads.length === 0) {
          this.set("userCancelled", true);
          this._uppyInstance.cancelAll();
        }
      });
    });

    this._uppyInstance.on("upload-progress", (file, progress) => {
      run(() => {
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
    });

    this._uppyInstance.on("upload", (data) => {
      run(() => {
        this._addNeedProcessing(data.fileIDs.length);

        const files = data.fileIDs.map((fileId) =>
          this._uppyInstance.getFile(fileId)
        );

        this.setProperties({
          isProcessingUpload: true,
          isCancellable: false,
        });

        files.forEach((file) => {
          // The inProgressUploads is meant to be used to display these uploads
          // in a UI, and Ember will only update the array in the UI if pushObject
          // is used to notify it.
          this.inProgressUploads.pushObject(
            EmberObject.create({
              fileName: file.name,
              id: file.id,
              progress: 0,
              extension: file.extension,
            })
          );
          const placeholder = this._uploadPlaceholder(file);
          this.placeholders[file.id] = {
            uploadPlaceholder: placeholder,
          };
          this.appEvents.trigger(
            `${this.eventPrefix}:insert-text`,
            placeholder
          );
          this.appEvents.trigger(
            `${this.eventPrefix}:upload-started`,
            file.name
          );
        });
      });
    });

    this._uppyInstance.on("upload-success", (file, response) => {
      run(() => {
        if (!this._uppyInstance) {
          return;
        }
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
    });

    this._uppyInstance.on("upload-error", this._handleUploadError);

    this._uppyInstance.on("complete", () => {
      run(() => {
        this.appEvents.trigger(`${this.eventPrefix}:all-uploads-complete`);
        this._reset();
      });
    });

    this._uppyInstance.on("cancel-all", () => {
      // uppyInstance.reset() also fires cancel-all, so we want to
      // only do the manual cancelling work if the user clicked cancel
      if (this.userCancelled) {
        Object.values(this.placeholders).forEach((data) => {
          run(() => {
            this.appEvents.trigger(
              `${this.eventPrefix}:replace-text`,
              data.uploadPlaceholder,
              ""
            );
          });
        });

        this.set("userCancelled", false);
        this._reset();

        this.appEvents.trigger(`${this.eventPrefix}:uploads-cancelled`);
      }
    });

    this._setupPreProcessors();
    this._setupUIPlugins();

    this.uploadTargetBound = true;
    this._uppyReady();
  },

  // This should be overridden in a child component if you need to
  // hook into uppy events and be sure that everything is already
  // set up for _uppyInstance.
  _uppyReady() {},

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
        run(() => {
          let placeholderData = this.placeholders[file.id];
          this.appEvents.trigger(
            `${this.eventPrefix}:replace-text`,
            placeholderData.processingPlaceholder,
            placeholderData.uploadPlaceholder
          );
        });
      },
      () => {
        run(() => {
          this.setProperties({
            isProcessingUpload: false,
            isCancellable: true,
          });
          this.appEvents.trigger(
            `${this.eventPrefix}:uploads-preprocessing-complete`
          );
        });
      }
    );
  },

  _setupUIPlugins() {
    this._uppyInstance.use(DropTarget, this._uploadDropTargetOptions());
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

    const { canUpload, canPasteHtml, types } = clipboardHelpers(event, {
      siteSettings: this.siteSettings,
      canUpload: true,
    });

    if (!canUpload || canPasteHtml || types.includes("text/plain")) {
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

  _bindMobileUploadButton() {
    if (this.site.mobileView) {
      this.mobileUploadButton = document.getElementById(
        this.mobileFileUploaderId
      );
      this.mobileUploadButtonEventListener = () => {
        document.getElementById(this.fileUploadElementId).click();
      };
      this.mobileUploadButton.addEventListener(
        "click",
        this.mobileUploadButtonEventListener,
        false
      );
    }
  },

  _unbindMobileUploadButton() {
    this.mobileUploadButton?.removeEventListener(
      "click",
      this.mobileUploadButtonEventListener
    );
  },

  _filenamePlaceholder(data) {
    return data.name.replace(/\u200B-\u200D\uFEFF]/g, "");
  },

  _resetUploadFilenamePlaceholder() {
    this.set("uploadFilenamePlaceholder", null);
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
