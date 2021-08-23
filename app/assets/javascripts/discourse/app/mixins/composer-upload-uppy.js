import Mixin from "@ember/object/mixin";
import { deepMerge } from "discourse-common/lib/object";
import UppyChecksum from "discourse/lib/uppy-checksum-plugin";
import UppyMediaOptimization from "discourse/lib/uppy-media-optimization-plugin";
import Uppy from "@uppy/core";
import DropTarget from "@uppy/drop-target";
import XHRUpload from "@uppy/xhr-upload";
import { warn } from "@ember/debug";
import I18n from "I18n";
import getURL from "discourse-common/lib/get-url";
import { clipboardHelpers } from "discourse/lib/utilities";
import { observes, on } from "discourse-common/utils/decorators";
import {
  bindFileInputChangeListener,
  displayErrorForUpload,
  getUploadMarkdown,
  validateUploadedFile,
} from "discourse/lib/uploads";
import { cacheShortUploadUrl } from "pretty-text/upload-short-url";

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
export default Mixin.create({
  @observes("composer.uploadCancelled")
  _cancelUpload() {
    if (!this.get("composer.uploadCancelled")) {
      return;
    }
    this.set("composer.uploadCancelled", false);
    this.set("userCancelled", true);

    this._uppyInstance.cancelAll();
  },

  @on("willDestroyElement")
  _unbindUploadTarget() {
    this.messageBus.unsubscribe("/uploads/composer");

    this.mobileUploadButton?.removeEventListener(
      "click",
      this.mobileUploadButtonEventListener
    );

    this.fileInputEl?.removeEventListener(
      "change",
      this.fileInputEventListener
    );

    this.element?.removeEventListener("paste", this.pasteEventListener);

    this.appEvents.off("composer:add-files", this._addFiles.bind(this));

    this._reset();

    if (this._uppyInstance) {
      this._uppyInstance.close();
      this._uppyInstance = null;
    }
  },

  _bindUploadTarget() {
    this.placeholders = {};
    this._preProcessorStatus = {};
    this.fileInputEl = document.getElementById("file-uploader");
    const isPrivateMessage = this.get("composer.privateMessage");

    this.appEvents.on("composer:add-files", this._addFiles.bind(this));

    this._unbindUploadTarget();
    this._bindFileInputChangeListener();
    this._bindPasteListener();
    this._bindMobileUploadButton();

    this._uppyInstance = new Uppy({
      id: "composer-uppy",
      autoProceed: true,

      // need to use upload_type because uppy overrides type with the
      // actual file type
      meta: deepMerge({ upload_type: "composer" }, this.data || {}),

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
          this.appEvents.trigger("composer:uploads-aborted");
        }
        return isUploading;
      },

      onBeforeUpload: (files) => {
        const fileCount = Object.keys(files).length;
        const maxFiles = this.siteSettings.simultaneous_uploads;

        // Limit the number of simultaneous uploads
        if (maxFiles > 0 && fileCount > maxFiles) {
          bootbox.alert(
            I18n.t("post.errors.too_many_dragged_and_dropped_files", {
              count: maxFiles,
            })
          );
          this.appEvents.trigger("composer:uploads-aborted");
          this._reset();
          return false;
        }
      },
    });

    this._uppyInstance.use(DropTarget, { target: this.element });
    this._uppyInstance.use(UppyChecksum, { capabilities: this.capabilities });

    // TODO (martin) Need a more automatic way to do this for preprocessor
    // plugins like UppyChecksum and UppyMediaOptimization so people don't
    // have to remember to do this, also want to wrap this.uppy.emit in those
    // classes so people don't have to remember to pass through the plugin class
    // name for the preprocess-X events.
    this._trackPreProcessorStatus(UppyChecksum);

    // TODO (martin) support for direct S3 uploads will come later, for now
    // we just want the regular /uploads.json endpoint to work well
    this._useXHRUploads();

    // TODO (martin) develop upload handler guidance and an API to use; will
    // likely be using uppy plugins for this
    this._uppyInstance.on("file-added", (file) => {
      if (isPrivateMessage) {
        file.meta.for_private_message = true;
      }
    });

    this._uppyInstance.on("progress", (progress) => {
      this.set("uploadProgress", progress);
    });

    this._uppyInstance.on("upload", (data) => {
      const files = data.fileIDs.map((fileId) =>
        this._uppyInstance.getFile(fileId)
      );

      this._eachPreProcessor((pluginName, status) => {
        status.needProcessing = files.length;
      });

      this.setProperties({
        isProcessingUpload: true,
        isCancellable: false,
      });

      files.forEach((file) => {
        const placeholder = this._uploadPlaceholder(file);
        this.placeholders[file.id] = {
          uploadPlaceholder: placeholder,
        };
        this.appEvents.trigger("composer:insert-text", placeholder);
        this.appEvents.trigger("composer:upload-started", file.name);
      });
    });

    this._uppyInstance.on("upload-success", (file, response) => {
      let upload = response.body;
      const markdown = this.uploadMarkdownResolvers.reduce(
        (md, resolver) => resolver(upload) || md,
        getUploadMarkdown(upload)
      );

      cacheShortUploadUrl(upload.short_url, upload);

      this.appEvents.trigger(
        "composer:replace-text",
        this.placeholders[file.id].uploadPlaceholder.trim(),
        markdown
      );

      this._resetUpload(file, { removePlaceholder: false });
      this.appEvents.trigger("composer:upload-success", file.name, upload);
    });

    this._uppyInstance.on("upload-error", (file, error, response) => {
      this._resetUpload(file, { removePlaceholder: true });

      if (!this.userCancelled) {
        displayErrorForUpload(response, this.siteSettings, file.name);
        this.appEvents.trigger("composer:upload-error", file);
      }
    });

    this._uppyInstance.on("complete", () => {
      this.appEvents.trigger("composer:all-uploads-complete");
      this._reset();
    });

    this._uppyInstance.on("cancel-all", () => {
      // uppyInstance.reset() also fires cancel-all, so we want to
      // only do the manual cancelling work if the user clicked cancel
      if (this.userCancelled) {
        Object.values(this.placeholders).forEach((data) => {
          this.appEvents.trigger(
            "composer:replace-text",
            data.uploadPlaceholder,
            ""
          );
        });

        this.set("userCancelled", false);
        this._reset();

        this.appEvents.trigger("composer:uploads-cancelled");
      }
    });

    this._setupPreprocessing();
  },

  _setupPreprocessing() {
    Object.keys(this.uploadProcessorActions).forEach((action) => {
      switch (action) {
        case "optimizeJPEG":
          this._uppyInstance.use(UppyMediaOptimization, {
            optimizeFn: this.uploadProcessorActions[action],
            runParallel: !this.site.isMobileDevice,
          });
          this._trackPreProcessorStatus(UppyMediaOptimization);
          break;
      }
    });

    this._uppyInstance.on("preprocess-progress", (pluginClass, file) => {
      this._preProcessorStatus[pluginClass].activeProcessing++;
      let placeholderData = this.placeholders[file.id];
      placeholderData.processingPlaceholder = `[${I18n.t(
        "processing_filename",
        {
          filename: file.name,
        }
      )}]()\n`;

      this.appEvents.trigger(
        "composer:replace-text",
        placeholderData.uploadPlaceholder,
        placeholderData.processingPlaceholder
      );
    });

    this._uppyInstance.on("preprocess-complete", (pluginClass, file) => {
      let placeholderData = this.placeholders[file.id];
      this.appEvents.trigger(
        "composer:replace-text",
        placeholderData.processingPlaceholder,
        placeholderData.uploadPlaceholder
      );
      const preProcessorStatus = this._preProcessorStatus[pluginClass];
      preProcessorStatus.activeProcessing--;
      preProcessorStatus.completeProcessing++;

      if (
        preProcessorStatus.completeProcessing ===
        preProcessorStatus.needProcessing
      ) {
        preProcessorStatus.allComplete = true;

        if (this._allPreprocessorsComplete()) {
          this.setProperties({
            isProcessingUpload: false,
            isCancellable: true,
          });
          this.appEvents.trigger("composer:uploads-preprocessing-complete");
        }
      }
    });
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
    const matchingPlaceholder = this.get("composer.reply").match(globalRegex);
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
    this._eachPreProcessor((pluginClass) => {
      this._preProcessorStatus[pluginClass] = {
        needProcessing: 0,
        activeProcessing: 0,
        completeProcessing: 0,
        allComplete: false,
      };
    });
    this.fileInputEl.value = "";
  },

  _resetUpload(file, opts) {
    if (opts.removePlaceholder) {
      this.appEvents.trigger(
        "composer:replace-text",
        this.placeholders[file.id].uploadPlaceholder,
        ""
      );
    }
  },

  _bindFileInputChangeListener() {
    this.fileInputEventListener = bindFileInputChangeListener(
      this.fileInputEl,
      this._addFiles.bind(this)
    );
  },

  _bindPasteListener() {
    this.pasteEventListener = function pasteListener(event) {
      if (
        document.activeElement !== document.querySelector(".d-editor-input")
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
        this._addFiles([...event.clipboardData.files]);
      }
    }.bind(this);

    this.element.addEventListener("paste", this.pasteEventListener);
  },

  _addFiles(files) {
    files = Array.isArray(files) ? files : [files];
    try {
      this._uppyInstance.addFiles(
        files.map((file) => {
          return {
            source: "composer",
            name: file.name,
            type: file.type,
            data: file,
          };
        })
      );
    } catch (err) {
      warn(`error adding files to uppy: ${err}`, {
        id: "discourse.upload.uppy-add-files-error",
      });
    }
  },

  _trackPreProcessorStatus(pluginClass) {
    this._preProcessorStatus[pluginClass.name] = {
      needProcessing: 0,
      activeProcessing: 0,
      completeProcessing: 0,
      allComplete: false,
    };
  },

  _eachPreProcessor(cb) {
    for (const [pluginClass, status] of Object.entries(
      this._preProcessorStatus
    )) {
      cb(pluginClass, status);
    }
  },

  _allPreprocessorsComplete() {
    let completed = [];
    this._eachPreProcessor((pluginClass, status) => {
      completed.push(status.allComplete);
    });
    return completed.every(Boolean);
  },

  showUploadSelector(toolbarEvent) {
    this.send("showUploadSelector", toolbarEvent);
  },
});
