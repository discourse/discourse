import Component from "@ember/component";
import {
  authorizedExtensions,
  authorizesAllExtensions,
} from "discourse/lib/uploads";
import { action } from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";

// This picker is intended to be used with UppyUploadMixin or with
// ComposerUploadUppy, which is why there are no change events registered
// for the input. They are handled by the uppy mixins directly.
export default Component.extend({
  fileInputId: null,
  fileInputClass: null,
  classNames: ["pick-files-button"],
  acceptedFileTypes: null,

  allowUpload: true,
  allowMultiple: false,
  showButton: false,

  @discourseComputed()
  acceptsAllFormats() {
    return (
      this.capabilities.isIOS ||
      authorizesAllExtensions(this.currentUser.staff, this.siteSettings)
    );
  },

  @discourseComputed()
  acceptedFormats() {
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
});
