import Component from "@glimmer/component";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { i18n } from "discourse-i18n";

export default class UppyBackupUploader extends Component {
  get uploadButtonText() {
    return this.args.uppyUpload.uploading
      ? i18n("admin.backups.upload.uploading_progress", {
          progress: this.args.uppyUpload.uploadProgress,
        })
      : i18n("admin.backups.upload.label");
  }

  <template>
    <span>
      <label
        class="btn btn-small btn-primary admin-backups-upload"
        disabled={{@uppyUpload.uploading}}
        title={{i18n "admin.backups.upload.title"}}
        ...attributes
      >
        {{this.uploadButtonText}}
        {{! Render modifiers don't autotrack, so upload state changes don't rebind the input }}
        <input
          accept=".gz"
          class="hidden-upload-field"
          disabled={{@uppyUpload.uploading}}
          type="file"
          {{didInsert @uppyUpload.attachFileInput}}
          {{willDestroy @uppyUpload.detachFileInput}}
        />
      </label>
    </span>
  </template>
}
