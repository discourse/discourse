import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import { isImage } from "discourse/lib/uploads";

export default Component.extend({
  IMAGE_TYPE: "image",

  tagName: "",
  classNames: "chat-upload",
  isDone: false,
  upload: null,
  onCancel: null,

  @discourseComputed("upload.{original_filename,fileName}")
  type(upload) {
    if (isImage(upload.original_filename || upload.fileName)) {
      return this.IMAGE_TYPE;
    }
  },

  @discourseComputed("isDone", "upload.{original_filename,fileName}")
  fileName(isDone, upload) {
    return isDone ? upload.original_filename : upload.fileName;
  },
});
