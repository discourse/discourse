import { notEmpty } from "@ember/object/computed";
import { action } from "@ember/object";
import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import UploadMixin from "discourse/mixins/upload";

const DEFAULT_GROUP = "default";

export default Component.extend(UploadMixin, {
  type: "emoji",
  uploadUrl: "/admin/customize/emojis",
  hasName: notEmpty("name"),
  hasGroup: notEmpty("group"),
  group: "default",
  emojiGroups: null,
  newEmojiGroups: null,
  tagName: null,

  didReceiveAttrs() {
    this._super(...arguments);

    this.set("newEmojiGroups", this.emojiGroups);
  },

  @discourseComputed("hasName", "uploading")
  addDisabled() {
    return !this.hasName || this.uploading;
  },

  uploadOptions() {
    return { sequentialUploads: true };
  },

  @action
  createEmojiGroup(group) {
    this.setProperties({
      newEmojiGroups: this.emojiGroups.concat([group]).uniq(),
      group
    });
  },

  @discourseComputed("hasName", "name", "hasGroup", "group")
  data(hasName, name, hasGroup, group) {
    const payload = {};

    if (hasName) {
      payload.name = name;
    }

    if (hasGroup && group !== DEFAULT_GROUP) {
      payload.group = group;
    }

    return payload;
  },

  validateUploadedFilesOptions() {
    return { imagesOnly: true };
  },

  uploadDone(upload) {
    this.done(upload, this.group);
    this.setProperties({ name: null, group: DEFAULT_GROUP });
  }
});
