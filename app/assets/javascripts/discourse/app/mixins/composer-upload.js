import Mixin from "@ember/object/mixin";
import I18n from "I18n";
import { next, run } from "@ember/runloop";
import getURL from "discourse-common/lib/get-url";
import { clipboardHelpers } from "discourse/lib/utilities";
import discourseComputed, {
  observes,
  on,
} from "discourse-common/utils/decorators";
import {
  displayErrorForUpload,
  getUploadMarkdown,
  validateUploadedFiles,
} from "discourse/lib/uploads";
import { cacheShortUploadUrl } from "pretty-text/upload-short-url";
import bootbox from "bootbox";

export default Mixin.create({
  _xhr: null,
  uploadProgress: 0,
  uploadFilenamePlaceholder: null,
  uploadProcessingFilename: null,
  uploadProcessingPlaceholdersAdded: false,

  @discourseComputed("uploadFilenamePlaceholder")
  uploadPlaceholder(uploadFilenamePlaceholder) {
    const clipboard = I18n.t("clipboard");
    const filename = uploadFilenamePlaceholder
      ? uploadFilenamePlaceholder
      : clipboard;

    let placeholder = `[${I18n.t("uploading_filename", { filename })}]()\n`;
    if (!this._cursorIsOnEmptyLine()) {
      placeholder = `\n${placeholder}`;
    }

    return placeholder;
  },

  @observes("composer.uploadCancelled")
  _cancelUpload() {
    if (!this.get("composer.uploadCancelled")) {
      return;
    }
    this.set("composer.uploadCancelled", false);

    if (this._xhr) {
      this._xhr._userCancelled = true;
      this._xhr.abort();
    }
    this._resetUpload(true);
  },

  _setUploadPlaceholderSend(data) {
    const filename = this._filenamePlaceholder(data);
    this.set("uploadFilenamePlaceholder", filename);

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
      data.orderNr = orderNr;
      const filenameWithOrderNr = `${filename}(${orderNr})`;
      this.set("uploadFilenamePlaceholder", filenameWithOrderNr);
    }
  },

  _setUploadPlaceholderDone(data) {
    const filename = this._filenamePlaceholder(data);

    if (data.orderNr) {
      const filenameWithOrderNr = `${filename}(${data.orderNr})`;
      this.set("uploadFilenamePlaceholder", filenameWithOrderNr);
    } else {
      this.set("uploadFilenamePlaceholder", filename);
    }
  },

  _filenamePlaceholder(data) {
    if (data.files) {
      return data.files[0].name.replace(/\u200B-\u200D\uFEFF]/g, "");
    } else {
      return data.name.replace(/\u200B-\u200D\uFEFF]/g, "");
    }
  },

  _resetUploadFilenamePlaceholder() {
    this.set("uploadFilenamePlaceholder", null);
  },

  _resetUpload(removePlaceholder) {
    next(() => {
      if (!this.element || this.isDestroying || this.isDestroyed) {
        return;
      }

      if (this._validUploads > 0) {
        this._validUploads--;
      }
      if (this._validUploads === 0) {
        this.setProperties({
          uploadProgress: 0,
          isUploading: false,
          isCancellable: false,
        });
      }
      if (removePlaceholder) {
        this.appEvents.trigger(
          "composer:replace-text",
          this.uploadPlaceholder,
          ""
        );
      }
      this._resetUploadFilenamePlaceholder();
    });
  },

  _bindUploadTarget() {
    if (!this.element || this.isDestroying || this.isDestroyed) {
      return;
    }

    this._unbindUploadTarget(); // in case it's still bound, let's clean it up first
    this._pasted = false;

    const $element = $(this.element);

    this.setProperties({
      uploadProgress: 0,
      isUploading: false,
      isProcessingUpload: false,
      isCancellable: false,
    });

    $.blueimp.fileupload.prototype.processActions = this.uploadProcessorActions;

    $element.fileupload({
      url: getURL(`/uploads.json?client_id=${this.messageBus.clientId}`),
      dataType: "json",
      pasteZone: $element,
      processQueue: this.uploadProcessorQueue,
    });

    $element
      .on("fileuploadprocessstart", () => {
        this.setProperties({
          uploadProgress: 0,
          isUploading: true,
          isProcessingUpload: true,
          isCancellable: false,
        });
      })
      .on("fileuploadprocess", (e, data) => {
        if (!this.uploadProcessingPlaceholdersAdded) {
          data.originalFiles
            .map((f) => f.name)
            .forEach((f) => {
              this.appEvents.trigger(
                "composer:insert-text",
                `[${I18n.t("processing_filename", {
                  filename: f,
                })}]()\n`
              );
            });
          this.uploadProcessingPlaceholdersAdded = true;
        }
        this.uploadProcessingFilename = data.files[data.index].name;
      })
      .on("fileuploadprocessstop", () => {
        this.setProperties({
          uploadProgress: 0,
          isUploading: false,
          isProcessingUpload: false,
          isCancellable: false,
        });
        this.uploadProcessingPlaceholdersAdded = false;
      });

    $element.on("fileuploadpaste", (e) => {
      this._pasted = true;

      if (!$(".d-editor-input").is(":focus")) {
        return;
      }

      const { canUpload, canPasteHtml, types } = clipboardHelpers(e, {
        siteSettings: this.siteSettings,
        canUpload: true,
      });

      if (!canUpload || canPasteHtml || types.includes("text/plain")) {
        e.preventDefault();
      }
    });

    $element.on("fileuploadsubmit", (e, data) => {
      const max = this.siteSettings.simultaneous_uploads;
      const fileCount = data.files.length;

      // Limit the number of simultaneous uploads
      if (max > 0 && fileCount > max) {
        bootbox.alert(
          I18n.t("post.errors.too_many_dragged_and_dropped_files", {
            count: max,
          })
        );
        return false;
      }

      // Look for a matching file upload handler contributed from a plugin
      if (fileCount === 1) {
        const file = data.files[0];
        const matchingHandler = this._findMatchingUploadHandler(file.name);
        if (matchingHandler && !matchingHandler.method(file, this)) {
          return false;
        }
      }

      // If no plugin, continue as normal
      const isPrivateMessage = this.get("composer.privateMessage");

      data.formData = { type: "composer" };
      if (isPrivateMessage) {
        data.formData.for_private_message = true;
      }
      if (this._pasted) {
        data.formData.pasted = true;
      }

      const opts = {
        user: this.currentUser,
        siteSettings: this.siteSettings,
        isPrivateMessage,
        allowStaffToUploadAnyFileInPm: this.siteSettings
          .allow_staff_to_upload_any_file_in_pm,
      };

      const isUploading = validateUploadedFiles(data.files, opts);

      run(() => {
        this.setProperties({ uploadProgress: 0, isUploading });
      });

      return isUploading;
    });

    $element.on("fileuploadprogressall", (e, data) => {
      run(() => {
        this.set(
          "uploadProgress",
          parseInt((data.loaded / data.total) * 100, 10)
        );
      });
    });

    $element.on("fileuploadsend", (e, data) => {
      run(() => {
        this._pasted = false;
        this._validUploads++;

        this._setUploadPlaceholderSend(data);

        if (this.uploadProcessingFilename) {
          this.appEvents.trigger(
            "composer:replace-text",
            `[${I18n.t("processing_filename", {
              filename: this.uploadProcessingFilename,
            })}]()`,
            this.uploadPlaceholder.trim()
          );
          this.uploadProcessingFilename = null;
        } else {
          this.appEvents.trigger(
            "composer:insert-text",
            this.uploadPlaceholder
          );
        }

        if (data.xhr && data.originalFiles.length === 1) {
          this.set("isCancellable", true);
          this._xhr = data.xhr();
        }
      });
    });

    $element.on("fileuploaddone", (e, data) => {
      run(() => {
        let upload = data.result;
        this._setUploadPlaceholderDone(data);
        if (!this._xhr || !this._xhr._userCancelled) {
          const markdown = this.uploadMarkdownResolvers.reduce(
            (md, resolver) => resolver(upload) || md,
            getUploadMarkdown(upload)
          );

          cacheShortUploadUrl(upload.short_url, upload);
          this.appEvents.trigger(
            "composer:replace-text",
            this.uploadPlaceholder.trim(),
            markdown
          );
          this._resetUpload(false);
        } else {
          this._resetUpload(true);
        }
      });
    });

    $element.on("fileuploadfail", (e, data) => {
      run(() => {
        this._setUploadPlaceholderDone(data);
        this._resetUpload(true);

        const userCancelled = this._xhr && this._xhr._userCancelled;
        this._xhr = null;

        if (!userCancelled) {
          displayErrorForUpload(data, this.siteSettings, data.files[0].name);
        }
      });
    });
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

  @on("willDestroyElement")
  _unbindUploadTarget() {
    this._validUploads = 0;
    const $uploadTarget = $(this.element);
    try {
      $uploadTarget.fileupload("destroy");
    } catch (e) {
      /* wasn't initialized yet */
    }
    $uploadTarget.off();
  },

  showUploadSelector(toolbarEvent) {
    this.send("showUploadSelector", toolbarEvent);
  },
});
