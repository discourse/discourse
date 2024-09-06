import Component from "@ember/component";
import { action } from "@ember/object";
import { notEmpty } from "@ember/object/computed";
import { isEmpty } from "@ember/utils";
import UppyUploadMixin from "discourse/mixins/uppy-upload";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

const DEFAULT_GROUP = "default";

export default class EmojiUploader extends Component.extend(UppyUploadMixin) {
  type = "emoji";
  uploadUrl = "/admin/customize/emojis";

  @notEmpty("name") hasName;
  @notEmpty("group") hasGroup;

  group = "default";
  emojiGroups = null;
  newEmojiGroups = null;
  tagName = null;
  preventDirectS3Uploads = true;

  didReceiveAttrs() {
    super.didReceiveAttrs(...arguments);
    this.set("newEmojiGroups", this.emojiGroups);
  }

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
  }

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
  }

  validateUploadedFilesOptions() {
    return { imagesOnly: true };
  }

  uploadDone(upload) {
    this.done(upload, this.group);
    this.set("name", null);
  }

  @action
  chooseFiles() {
    this.fileInputEl.click();
  }

  @discourseComputed("uploading", "uploadProgress")
  buttonLabel(uploading, uploadProgress) {
    if (uploading) {
      return `${I18n.t("admin.emoji.uploading")} ${uploadProgress}%`;
    } else {
      return I18n.t("admin.emoji.add");
    }
  }

  @discourseComputed("uploading")
  buttonIcon(uploading) {
    if (uploading) {
      return "spinner";
    } else {
      return "plus";
    }
  }
}
