import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { isEmpty } from "@ember/utils";
import withEventValue from "discourse/helpers/with-event-value";
import { uniqueItemsFromArray } from "discourse/lib/array-tools";
import { resettableTracked } from "discourse/lib/tracked-tools";
import UppyUpload from "discourse/lib/uppy/uppy-upload";
import ComboBox from "discourse/select-kit/components/combo-box";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

const DEFAULT_GROUP = "default";

export default class EmojiUploader extends Component {
  @tracked name;
  @tracked group = DEFAULT_GROUP;

  /** @type {string[] | null} */
  @resettableTracked newEmojiGroups = this.args.emojiGroups;

  uppyUpload = new UppyUpload(this, {
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
        this.name = null;
      }

      if (!isEmpty(this.group) && this.group !== DEFAULT_GROUP) {
        payload.group = this.group;
      }

      return payload;
    },

    uploadDone: (upload) => {
      this.args.done(upload, this.group);
      this.name = null;
    },
  });

  get buttonLabel() {
    if (this.uppyUpload.uploading) {
      return `${i18n("admin.emoji.uploading")} ${this.uppyUpload.uploadProgress}%`;
    } else {
      return i18n("admin.emoji.choose_files");
    }
  }

  @action
  createEmojiGroup(group) {
    if (group !== DEFAULT_GROUP) {
      this.newEmojiGroups = uniqueItemsFromArray(
        this.args.emojiGroups.concat([group])
      );
    }
    this.group = group;
  }

  @action
  chooseFiles() {
    this.uppyUpload.openPicker();
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
              class="form-kit__control-input"
              id="emoji-name"
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
              @content={{this.newEmojiGroups}}
              @id="emoji-group-selector"
              @name="group"
              @nameProperty={{null}}
              @onChange={{this.createEmojiGroup}}
              @options={{hash allowAny=true}}
              @value={{this.group}}
              @valueProperty={{null}}
            />
          </div>
        </div>
      </div>
      <div class="control-group">
        <div class="input">
          <input
            accept=".gif,.png,.svg"
            class="hidden-upload-field"
            disabled={{this.uppyUpload.uploading}}
            multiple="true"
            type="file"
            {{didInsert this.uppyUpload.setup}}
          />
          <DButton
            class="btn-primary"
            @action={{this.chooseFiles}}
            @disabled={{this.uppyUpload.uploading}}
            @translatedLabel={{this.buttonLabel}}
          />
        </div>
      </div>
    </div>
  </template>
}
