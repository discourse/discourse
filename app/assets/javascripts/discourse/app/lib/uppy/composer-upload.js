import { warn } from "@ember/debug";
import EmberObject from "@ember/object";
import { getOwner, setOwner } from "@ember/owner";
import { run } from "@ember/runloop";
import { service } from "@ember/service";
import Uppy from "@uppy/core";
import DropTarget from "@uppy/drop-target";
import XHRUpload from "@uppy/xhr-upload";
import { cacheShortUploadUrl } from "pretty-text/upload-short-url";
import { updateCsrfToken } from "discourse/lib/ajax";
import ComposerVideoThumbnailUppy from "discourse/lib/composer-video-thumbnail-uppy";
import { bind } from "discourse/lib/decorators";
import getURL from "discourse/lib/get-url";
import {
  bindFileInputChangeListener,
  displayErrorForBulkUpload,
  displayErrorForUpload,
  getUploadMarkdown,
  isImage,
  validateUploadedFile,
} from "discourse/lib/uploads";
import UppyS3Multipart from "discourse/lib/uppy/s3-multipart";
import UppyWrapper from "discourse/lib/uppy/wrapper";
import UppyChecksum from "discourse/lib/uppy-checksum-plugin";
import { clipboardHelpers } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default class UppyComposerUpload {
  @service dialog;
  @service session;
  @service siteSettings;
  @service appEvents;
  @service currentUser;
  @service site;
  @service capabilities;
  @service messageBus;
  @service composer;

  uppyWrapper;

  uploadRootPath = "/uploads";
  uppyId = "composer-editor-uppy";
  uploadType = "composer";
  editorInputClass = ".d-editor-input";
  mobileFileUploaderId = "mobile-file-upload";
  fileUploadElementId;

  composerEventPrefix;
  composerModel;
  uploadMarkdownResolvers;
  uploadPreProcessors;
  uploadHandlers;

  /** @type {PlaceholderHandler} */
  placeholderHandler;

  #inProgressUploads = [];
  #bufferedUploadErrors = [];
  #consecutiveImages = [];

  #uploadTargetBound = false;
  #userCancelled = false;

  #fileInputEl;
  #editorEl;

  constructor(
    owner,
    {
      composerEventPrefix,
      composerModel,
      uploadMarkdownResolvers,
      uploadPreProcessors,
      uploadHandlers,
      fileUploadElementId,
    }
  ) {
    setOwner(this, owner);
    this.uppyWrapper = new UppyWrapper(owner);
    this.composerEventPrefix = composerEventPrefix;
    this.composerModel = composerModel;
    this.uploadMarkdownResolvers = uploadMarkdownResolvers;
    this.uploadPreProcessors = uploadPreProcessors;
    this.uploadHandlers = uploadHandlers;
    this.fileUploadElementId = fileUploadElementId;
  }

  @bind
  _cancelUpload(data) {
    if (data) {
      // Single file
      this.uppyWrapper.uppyInstance.removeFile(data.fileId);
    } else {
      // All files
      this.#userCancelled = true;
      this.uppyWrapper.uppyInstance.cancelAll();
    }
  }

  teardown() {
    if (!this.#uploadTargetBound) {
      return;
    }

    this.#fileInputEl?.removeEventListener(
      "change",
      this.fileInputEventListener
    );

    this.#editorEl?.removeEventListener("paste", this._pasteEventListener, {
      capture: true,
    });

    this.appEvents.off(`${this.composerEventPrefix}:add-files`, this._addFiles);
    this.appEvents.off(
      `${this.composerEventPrefix}:cancel-upload`,
      this._cancelUpload
    );

    this.#reset();

    if (this.uppyWrapper.uppyInstance) {
      this.uppyWrapper.uppyInstance.destroy();
      this.uppyWrapper.uppyInstance = null;
    }

    this.#unbindMobileUploadButton();
    this.#uploadTargetBound = false;
  }

  #abortAndReset() {
    this.appEvents.trigger(`${this.composerEventPrefix}:uploads-aborted`);
    this.#reset();
    return false;
  }

  setup(element) {
    this.#editorEl = element;
    this.#fileInputEl = document.getElementById(this.fileUploadElementId);

    this.appEvents.on(`${this.composerEventPrefix}:add-files`, this._addFiles);
    this.appEvents.on(
      `${this.composerEventPrefix}:cancel-upload`,
      this._cancelUpload
    );

    this.fileInputEventListener = bindFileInputChangeListener(
      this.#fileInputEl,
      this._addFiles
    );
    this.#editorEl.addEventListener("paste", this._pasteEventListener, {
      capture: true,
    });

    this.uppyWrapper.uppyInstance = new Uppy({
      id: this.uppyId,
      autoProceed: true,

      // need to use upload_type because uppy overrides type with the
      // actual file type
      meta: { upload_type: this.uploadType },

      onBeforeFileAdded: (currentFile) => {
        const validationOpts = {
          user: this.currentUser,
          siteSettings: this.siteSettings,
          isPrivateMessage: this.composerModel.privateMessage,
          allowStaffToUploadAnyFileInPm:
            this.siteSettings.allow_staff_to_upload_any_file_in_pm,
        };

        const isUploading = validateUploadedFile(currentFile, validationOpts);

        this.composer.setProperties({
          uploadProgress: 0,
          isUploading,
          isCancellable: isUploading,
        });

        if (!isUploading) {
          this.appEvents.trigger(`${this.composerEventPrefix}:uploads-aborted`);
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
          const matchingHandler = this.#findMatchingUploadHandler(file.name);
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
            return this.#abortAndReset();
          }
        }

        // Limit the number of simultaneous uploads, for files which have
        // _not_ been handled by an upload handler.
        const fileCount = Object.keys(unhandledFiles).length;
        if (maxFiles > 0 && fileCount > maxFiles) {
          this.dialog.alert(
            i18n("post.errors.too_many_dragged_and_dropped_files", {
              count: maxFiles,
            })
          );
          return this.#abortAndReset();
        }

        // uppy uses this new object to track progress of remaining files
        return unhandledFiles;
      },
    });

    if (this.siteSettings.enable_upload_debug_mode) {
      this.uppyWrapper.debug.instrumentUploadTimings(
        this.uppyWrapper.uppyInstance
      );
    }

    if (this.siteSettings.enable_direct_s3_uploads) {
      new UppyS3Multipart(getOwner(this), {
        uploadRootPath: this.uploadRootPath,
        uppyWrapper: this.uppyWrapper,
        errorHandler: this._handleUploadError,
      }).apply(this.uppyWrapper.uppyInstance);
    } else {
      this.#useXHRUploads();
    }

    this.uppyWrapper.uppyInstance.on("file-added", (file) => {
      run(() => {
        if (this.composerModel.privateMessage) {
          file.meta.for_private_message = true;
        }

        if (isImage(file.name)) {
          this.#consecutiveImages.push(file.name);
        }
      });
    });

    this.uppyWrapper.uppyInstance.on("progress", (progress) => {
      run(() => {
        if (this.isDestroying || this.isDestroyed) {
          return;
        }

        this.composer.set("uploadProgress", progress);
      });
    });

    this.uppyWrapper.uppyInstance.on("file-removed", (file, reason) => {
      run(() => {
        // we handle the cancel-all event specifically, so no need
        // to do anything here. this event is also fired when some files
        // are handled by an upload handler
        if (reason === "cancel-all") {
          return;
        }
        this.appEvents.trigger(
          `${this.composerEventPrefix}:upload-cancelled`,
          file.id
        );
        file.meta.cancelled = true;
        this.#removeInProgressUpload(file.id);
        this.#resetUpload(file);
        if (this.#inProgressUploads.length === 0) {
          this.#userCancelled = true;
          this.uppyWrapper.uppyInstance.cancelAll();
        }
      });
    });

    this.uppyWrapper.uppyInstance.on("upload-progress", (file, progress) => {
      run(() => {
        if (this.isDestroying || this.isDestroyed) {
          return;
        }
        const upload = this.#inProgressUploads.find(
          (upl) => upl.id === file.id
        );
        if (upload) {
          const percentage = Math.round(
            (progress.bytesUploaded / progress.bytesTotal) * 100
          );
          upload.set("progress", percentage);
        }
      });
    });

    this.uppyWrapper.uppyInstance.on("upload", (uploadId, files) => {
      run(() => {
        this.uppyWrapper.addNeedProcessing(files.length);

        this.composer.setProperties({
          isProcessingUpload: true,
          isCancellable: false,
        });

        files.forEach((file) => {
          // The inProgressUploads is meant to be used to display these uploads
          // in a UI, and Ember will only update the array in the UI if pushObject
          // is used to notify it.
          this.#inProgressUploads.pushObject(
            EmberObject.create({
              fileName: file.name,
              id: file.id,
              progress: 0,
              extension: file.extension,
            })
          );

          if (!file.meta.skipPlaceholder) {
            this.placeholderHandler.insert(file);
          }

          this.appEvents.trigger(
            `${this.composerEventPrefix}:upload-started`,
            file.name
          );
        });

        const MIN_IMAGES_TO_AUTO_GRID = 3;
        if (
          this.siteSettings.experimental_auto_grid_images &&
          this.#consecutiveImages?.length >= MIN_IMAGES_TO_AUTO_GRID
        ) {
          this.#autoGridImages();
        }
      });
    });

    this.uppyWrapper.uppyInstance.on("upload-success", (file, response) => {
      run(async () => {
        if (!this.uppyWrapper.uppyInstance) {
          return;
        }
        let upload = response.body;

        const markdown = await this.uploadMarkdownResolvers.reduce(
          (md, resolver) => resolver(upload) || md,
          getUploadMarkdown(upload)
        );

        cacheShortUploadUrl(upload.short_url, upload);

        new ComposerVideoThumbnailUppy(getOwner(this)).generateVideoThumbnail(
          file,
          upload.url,

          // This callback is fired even if the thumbnail callnot be generated,
          // e.g. if video_thumbnails_enabled is false or if the file is not a video.
          () => {
            this.#removeInProgressUpload(file.id);

            if (!file.meta.skipPlaceholder) {
              this.placeholderHandler.success(file, markdown);
            }

            this.appEvents.trigger(
              `${this.composerEventPrefix}:upload-success`,
              file.name,
              upload
            );

            if (this.#inProgressUploads.length === 0) {
              this.appEvents.trigger(
                `${this.composerEventPrefix}:all-uploads-complete`
              );

              this.#displayBufferedErrors();
              this.#reset();
            }
          }
        );
      });
    });

    this.uppyWrapper.uppyInstance.on("upload-error", this._handleUploadError);

    this.uppyWrapper.uppyInstance.on("cancel-all", () => {
      // Do the manual cancelling work only if the user clicked cancel
      if (this.#userCancelled) {
        this.placeholderHandler.cancelAll();
        this.#userCancelled = false;
        this.#reset();

        this.appEvents.trigger(`${this.composerEventPrefix}:uploads-cancelled`);
      }
    });

    this.#setupPreProcessors();

    this.uppyWrapper.uppyInstance.use(DropTarget, { target: element });

    this.#uploadTargetBound = true;
    this.#bindMobileUploadButton();
  }

  @bind
  _handleUploadError(file, error, response) {
    this.#removeInProgressUpload(file.id);
    this.#resetUpload(file);

    file.meta.error = error;

    if (!this.#userCancelled) {
      this.#bufferUploadError(response || error, file.name);
      this.appEvents.trigger(`${this.composerEventPrefix}:upload-error`, file);
    }
    if (this.#inProgressUploads.length === 0) {
      this.#displayBufferedErrors();
      this.#reset();
    }
  }

  #removeInProgressUpload(fileId) {
    this.#inProgressUploads = this.#inProgressUploads.filter(
      (upl) => upl.id !== fileId
    );
  }

  #displayBufferedErrors() {
    if (this.#bufferedUploadErrors.length === 0) {
      return;
    } else if (this.#bufferedUploadErrors.length === 1) {
      displayErrorForUpload(
        this.#bufferedUploadErrors[0].data,
        this.siteSettings,
        this.#bufferedUploadErrors[0].fileName
      );
    } else {
      displayErrorForBulkUpload(this.#bufferedUploadErrors);
    }
  }

  #bufferUploadError(data, fileName) {
    this.#bufferedUploadErrors.push({ data, fileName });
  }

  #setupPreProcessors() {
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
        this.uppyWrapper.useUploadPlugin(
          pluginClass,
          optionsResolverFn({
            composerModel: this.composerModel,
            capabilities: this.capabilities,
            isMobileDevice: this.capabilities.isMobileDevice,
          })
        );
      });

    this.uppyWrapper.onPreProcessProgress((file) => {
      this.placeholderHandler.progress(file);
    });

    this.uppyWrapper.onPreProcessComplete(
      (file) => {
        run(() => {
          this.placeholderHandler.progressComplete(file);
        });
      },
      () => {
        run(() => {
          this.composer.setProperties({
            isProcessingUpload: false,
            isCancellable: true,
          });
          this.appEvents.trigger(
            `${this.composerEventPrefix}:uploads-preprocessing-complete`
          );
        });
      }
    );
  }

  #useXHRUploads() {
    this.uppyWrapper.uppyInstance.use(XHRUpload, {
      endpoint: getURL(`/uploads.json?client_id=${this.messageBus.clientId}`),
      shouldRetry: () => false,
      headers: () => ({
        "X-CSRF-Token": this.session.csrfToken,
      }),
    });
  }

  #reset() {
    this.uppyWrapper.uppyInstance?.cancelAll();
    this.composer.setProperties({
      uploadProgress: 0,
      isUploading: false,
      isProcessingUpload: false,
      isCancellable: false,
    });
    this.#inProgressUploads = [];
    this.#bufferedUploadErrors = [];
    this.#consecutiveImages = [];
    this.uppyWrapper.resetPreProcessors();
    this.#fileInputEl.value = "";
  }

  #resetUpload(file) {
    this.placeholderHandler.cancel(file);
  }

  @bind
  _pasteEventListener(event) {
    if (
      !document.querySelector(this.editorInputClass)?.contains(event.target)
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
      event.preventDefault();
      this._addFiles([...event.clipboardData.files], { pasted: true });
    }
  }

  @bind
  async _addFiles(files, opts = {}) {
    if (!this.session.csrfToken) {
      await updateCsrfToken();
    }

    files = Array.isArray(files) ? files : [files];

    try {
      this.uppyWrapper.uppyInstance.addFiles(
        files.map((file) => {
          return {
            source: this.uppyId,
            name: file.name,
            type: file.type,
            data: file,
            meta: {
              pasted: opts.pasted,
              skipPlaceholder: opts.skipPlaceholder,
            },
          };
        })
      );
    } catch (err) {
      warn(`error adding files to uppy: ${err}`, {
        id: "discourse.upload.uppy-add-files-error",
      });
    }
  }

  #bindMobileUploadButton() {
    if (this.site.mobileView) {
      this.mobileUploadButton = document.getElementById(
        this.mobileFileUploaderId
      );
      this.mobileUploadButton?.addEventListener(
        "click",
        this._mobileUploadButtonEventListener,
        false
      );
    }
  }

  @bind
  _mobileUploadButtonEventListener() {
    this.#fileInputEl.click();
  }

  #unbindMobileUploadButton() {
    this.mobileUploadButton?.removeEventListener(
      "click",
      this._mobileUploadButtonEventListener
    );
  }

  #findMatchingUploadHandler(fileName) {
    return this.uploadHandlers.find((handler) => {
      const ext = handler.extensions.join("|");
      const regex = new RegExp(`\\.(${ext})$`, "i");
      return regex.test(fileName);
    });
  }

  #autoGridImages() {
    const reply = this.composerModel.get("reply");
    const imagesToWrapGrid = new Set(this.#consecutiveImages);

    const uploadingText = i18n("uploading_filename", {
      filename: "%placeholder%",
    });
    const uploadingTextMatch = uploadingText.match(
      /^.*(?=: %placeholder%\s?…)/
    );

    if (!uploadingTextMatch || !uploadingTextMatch[0]) {
      return;
    }

    const uploadingImagePattern = new RegExp(
      "\\[" +
        uploadingTextMatch[0].trim() +
        "\\s?: ([^\\]]+?)\\.\\w+\\s?…\\]\\(\\)",
      "g"
    );

    const matches = reply.match(uploadingImagePattern) || [];
    const foundImages = [];

    const existingGridPattern = /\[grid\]([\s\S]*?)\[\/grid\]/g;
    const gridMatches = reply.match(existingGridPattern);

    matches.forEach((imagePlaceholder) => {
      imagePlaceholder = imagePlaceholder.trim();

      const filenamePattern = new RegExp(
        "\\[" +
          uploadingTextMatch[0].trim() +
          "\\s?: ([^\\]]+?)\\s?\\…\\]\\(\\)"
      );

      const filenameMatch = imagePlaceholder.match(filenamePattern);

      if (filenameMatch && filenameMatch[1]) {
        const filename = filenameMatch[1];

        const isWithinGrid = gridMatches?.some((gridContent) =>
          gridContent.includes(imagePlaceholder)
        );

        if (!isWithinGrid && imagesToWrapGrid.has(filename)) {
          foundImages.push(imagePlaceholder);
          imagesToWrapGrid.delete(filename);

          // Check if we've found all the images
          if (imagesToWrapGrid.size === 0) {
            return;
          }
        }
      }
    });

    // Check if all consecutive images have been found
    if (foundImages.length === this.#consecutiveImages.length) {
      const firstImageMarkdown = foundImages[0];
      const lastImageMarkdown = foundImages[foundImages.length - 1];

      const startIndex = reply.indexOf(firstImageMarkdown);
      const endIndex =
        reply.indexOf(lastImageMarkdown) + lastImageMarkdown.length;

      if (startIndex !== -1 && endIndex !== -1) {
        const textArea = this.#editorEl.querySelector(this.editorInputClass);
        if (textArea) {
          textArea.focus();
          textArea.selectionStart = startIndex;
          textArea.selectionEnd = endIndex;
          this.appEvents.trigger(
            `${this.composerEventPrefix}:apply-surround`,
            "[grid]",
            "[/grid]",
            "grid_surround",
            { useBlockMode: true }
          );
        }
      }
    }

    // Clear found images for the next consecutive images:
    this.#consecutiveImages.length = 0;
    foundImages.length = 0;
  }
}
