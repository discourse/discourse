import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import UppyUpload from "discourse/lib/uppy/uppy-upload";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class WatchedWordUploader extends Component {
  @service dialog;

  uppyUpload = new UppyUpload(getOwner(this), {
    id: "watched-word-uploader",
    type: "txt",
    uploadUrl: "/admin/customize/watched_words/upload",
    preventDirectS3Uploads: true,
    validateUploadedFilesOptions: {
      skipValidation: true,
    },
    perFileData: () => ({ action_key: this.args.actionKey }),
    uploadDone: () => {
      this.dialog.alert(i18n("admin.watched_words.form.upload_successful"));
      this.args.done();
    },
  });

  get addDisabled() {
    return this.uppyUpload?.uploading;
  }

  set addDisabled(value) {
    this.uppyUpload.uploading = value;
  }

  <template>
    <div class="watched-words-uploader" ...attributes>
      <label class="btn btn-default {{if this.addDisabled 'disabled'}}">
        {{dIcon "upload"}}
        {{i18n "admin.watched_words.form.upload"}}
        <input
          class="hidden-upload-field"
          disabled={{this.addDisabled}}
          type="file"
          {{didInsert this.uppyUpload.setup}}
        />
      </label>
    </div>
  </template>
}
