import { notEmpty, not } from "@ember/object/computed";
import Component from "@ember/component";
import { default as discourseComputed } from "discourse-common/utils/decorators";
import UploadMixin from "discourse/mixins/upload";

export default Component.extend(UploadMixin, {
  type: "emoji",
  uploadUrl: "/admin/customize/emojis",
  hasName: notEmpty("name"),
  addDisabled: not("hasName"),
  group: "default",

  uploadOptions() {
    return {
      sequentialUploads: true
    };
  },

  @discourseComputed("hasName", "name", "group")
  data(hasName, name, group) {
    return hasName ? { name, group } : {};
  },

  validateUploadedFilesOptions() {
    return { imagesOnly: true };
  },

  uploadDone(upload) {
    this.setProperties({ name: null, group: "default" });
    this.done(upload);
  }
});
