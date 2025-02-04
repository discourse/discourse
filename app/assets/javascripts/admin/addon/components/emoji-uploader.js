import Component from "@ember/component";
import { action } from "@ember/object";
import { notEmpty } from "@ember/object/computed";
import { getOwner } from "@ember/owner";
import { isEmpty } from "@ember/utils";
import discourseComputed from "discourse/lib/decorators";
import UppyUpload from "discourse/lib/uppy/uppy-upload";
import { i18n } from "discourse-i18n";
const DEFAULT_GROUP = "default";

export default class EmojiUploader extends Component {
  uppyUpload = new UppyUpload(getOwner(this), {
    id: "emoji-uploader",
    type: "emoji",
    uploadUrl: "/admin/config/emoji",
    preventDirectS3Uploads: true,
    validateUploadedFilesOptions: {
      imagesOnly: true,
    },

    perFileData: () => {
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

    uploadDone: (upload) => {
      this.done(upload, this.group);
      this.set("name", null);
    },
  });

  @notEmpty("name") hasName;
  @notEmpty("group") hasGroup;

  group = "default";
  emojiGroups = null;
  newEmojiGroups = null;
  tagName = null;

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

  @action
  chooseFiles() {
    this.uppyUpload.openPicker();
  }

  @discourseComputed("uppyUpload.uploading", "uppyUpload.uploadProgress")
  buttonLabel(uploading, uploadProgress) {
    if (uploading) {
      return `${i18n("admin.emoji.uploading")} ${uploadProgress}%`;
    } else {
      return i18n("admin.emoji.choose_files");
    }
  }

  @discourseComputed("uppyUpload.uploading")
  buttonIcon(uploading) {
    if (uploading) {
      return "spinner";
    } else {
      return "plus";
    }
  }
}
