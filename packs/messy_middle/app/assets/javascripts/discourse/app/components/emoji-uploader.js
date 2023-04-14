import Component from "@ember/component";
import I18n from "I18n";
import { isEmpty } from "@ember/utils";
import UppyUploadMixin from "discourse/mixins/uppy-upload";
import { action } from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";
import { notEmpty } from "@ember/object/computed";

const DEFAULT_GROUP = "default";

export default Component.extend(UppyUploadMixin, {
  type: "emoji",
  uploadUrl: "/admin/customize/emojis",
  hasName: notEmpty("name"),
  hasGroup: notEmpty("group"),
  group: "default",
  emojiGroups: null,
  newEmojiGroups: null,
  tagName: null,
  preventDirectS3Uploads: true,

  didReceiveAttrs() {
    this._super(...arguments);
    this.set("newEmojiGroups", this.emojiGroups);
  },

  @action
  createEmojiGroup(group) {
    let newEmojiGroups = this.newEmojiGroups;
    if (group !== DEFAULT_GROUP) {
      newEmojiGroups = this.emojiGroups.concat([group]).uniq();
    }
    this.setProperties({
      newEmojiGroups,
      group,
    });
  },

  _perFileData() {
    const payload = {};

    if (!isEmpty(this.name)) {
      payload.name = this.name;

      // if uploading multiple files, we can't use the name for every emoji
      this.set("name", null);
    }

    if (!isEmpty(this.group) && this.group !== DEFAULT_GROUP) {
      payload.group = this.group;
    }

    return payload;
  },

  validateUploadedFilesOptions() {
    return { imagesOnly: true };
  },

  uploadDone(upload) {
    this.done(upload, this.group);
    this.set("name", null);
  },

  @action
  chooseFiles() {
    this.fileInputEl.click();
  },

  @discourseComputed("uploading", "uploadProgress")
  buttonLabel(uploading, uploadProgress) {
    if (uploading) {
      return `${I18n.t("admin.emoji.uploading")} ${uploadProgress}%`;
    } else {
      return I18n.t("admin.emoji.add");
    }
  },

  @discourseComputed("uploading")
  buttonIcon(uploading) {
    if (uploading) {
      return "spinner";
    } else {
      return "plus";
    }
  },
});
