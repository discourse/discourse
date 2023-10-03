import Component from "@ember/component";
import { isBlank } from "@ember/utils";
import {
  authorizedExtensions,
  authorizesAllExtensions,
} from "discourse/lib/uploads";
import { action } from "@ember/object";
import discourseComputed, { bind } from "discourse-common/utils/decorators";
import I18n from "I18n";
import { inject as service } from "@ember/service";

// This picker is intended to be used with UppyUploadMixin or with
// ComposerUploadUppy, which is why there are no change events registered
// for the input. They are handled by the uppy mixins directly.
//
// However, if you provide an onFilesPicked action to this component, the change
// binding will still be added, and the file type will be validated here. This
// is sometimes useful if you need to do something outside the uppy upload with
// the file, such as directly using JSON or CSV data from a file in JS.
export default Component.extend({
  dialog: service(),
  fileInputId: null,
  fileInputClass: null,
  fileInputDisabled: false,
  classNames: ["pick-files-button"],
  acceptedFormatsOverride: null,
  allowMultiple: false,
  showButton: false,

  didInsertElement() {
    this._super(...arguments);

    if (this.onFilesPicked) {
      const fileInput = this.element.querySelector("input");
      this.set("fileInput", fileInput);
      fileInput.addEventListener("change", this.onChange, false);
    }
  },

  willDestroyElement() {
    this._super(...arguments);

    if (this.onFilesPicked) {
      this.fileInput.removeEventListener("change", this.onChange);
    }
  },

  @bind
  onChange() {
    const files = this.fileInput.files;
    this._filesPicked(files);
  },

  @discourseComputed()
  acceptsAllFormats() {
    return (
      this.capabilities.isIOS ||
      authorizesAllExtensions(this.currentUser.staff, this.siteSettings)
    );
  },

  @discourseComputed()
  acceptedFormats() {
    // the acceptedFormatsOverride can be a list of extensions or mime types
    if (!isBlank(this.acceptedFormatsOverride)) {
      return this.acceptedFormatsOverride;
    }

    const extensions = authorizedExtensions(
      this.currentUser.staff,
      this.siteSettings
    );

    return extensions.map((ext) => `.${ext}`).join();
  },

  @action
  openSystemFilePicker() {
    this.fileInput.click();
  },

  _filesPicked(files) {
    if (!files || !files.length) {
      return;
    }

    if (!this._haveAcceptedTypes(files)) {
      const message = I18n.t("pick_files_button.unsupported_file_picked", {
        types: this.acceptedFileTypesString,
      });
      this.dialog.alert(message);
      return;
    }
  },

  _haveAcceptedTypes(files) {
    for (const file of files) {
      if (!this._hasAcceptedExtensionOrType(file)) {
        return false;
      }
    }
    return true;
  },

  _hasAcceptedExtensionOrType(file) {
    const extension = this._fileExtension(file.name);
    return (
      this.acceptedFormats.includes(`.${extension}`) ||
      this.acceptedFormats.includes(file.type)
    );
  },

  _fileExtension(fileName) {
    return fileName.split(".").pop();
  },
});
