import Component, { Input } from "@ember/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { notEmpty } from "@ember/object/computed";
import { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { isEmpty } from "@ember/utils";
import DButton from "discourse/components/d-button";
import withEventValue from "discourse/helpers/with-event-value";
import discourseComputed from "discourse/lib/decorators";
import UppyUpload from "discourse/lib/uppy/uppy-upload";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

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

  <template>
    <div class="form-kit">
      <div
        class="form-kit__container form-kit__field form-kit__field-input-text"
      >
        <label class="form-kit__container-title">
          {{i18n "admin.emoji.name"}}
        </label>
        <div class="form-kit__container-content --large">
          <div class="form-kit__control-input-wrapper">
            <Input
              id="emoji-name"
              class="form-kit__control-input"
              name="name"
              @value={{readonly this.name}}
              {{on "input" (withEventValue (fn (mut this.name)))}}
            />
          </div>
        </div>
      </div>
      <div
        class="form-kit__container form-kit__field form-kit__field-input-combo-box"
      >
        <label class="form-kit__container-title">
          {{i18n "admin.emoji.group"}}
        </label>
        <div class="form-kit__container-content --large">
          <div class="form-kit__control-input-wrapper">
            <ComboBox
              @name="group"
              @id="emoji-group-selector"
              @value={{this.group}}
              @content={{this.newEmojiGroups}}
              @onChange={{this.createEmojiGroup}}
              @valueProperty={{null}}
              @nameProperty={{null}}
              @options={{hash allowAny=true}}
            />
          </div>
        </div>
      </div>
      <div class="control-group">
        <div class="input">
          <input
            {{didInsert this.uppyUpload.setup}}
            class="hidden-upload-field"
            disabled={{this.uppyUpload.uploading}}
            type="file"
            multiple="true"
            accept=".png,.gif"
          />
          <DButton
            @translatedLabel={{this.buttonLabel}}
            @action={{this.chooseFiles}}
            @disabled={{this.uppyUpload.uploading}}
            class="btn-primary"
          />
        </div>
      </div>
    </div>
  </template>
}
