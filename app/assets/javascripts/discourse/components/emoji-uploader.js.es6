import { notEmpty, not } from "@ember/object/computed";
import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import UploadMixin from "discourse/mixins/upload";

export default Component.extend(UploadMixin, {
  type: "emoji",
  uploadUrl: "/admin/customize/emojis",
  hasName: notEmpty("name"),
  addDisabled: not("hasName"),

  uploadOptions() {
    return {
      sequentialUploads: true
    };
  },

  @discourseComputed("hasName", "name")
  data(hasName, name) {
    return hasName ? { name } : {};
  },

  validateUploadedFilesOptions() {
    return { imagesOnly: true };
  },

  uploadDone(upload) {
    this.set("name", null);
    this.done(upload);
  }
});
