import Component from "@ember/component";
import { alias } from "@ember/object/computed";
import { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { classNames } from "@ember-decorators/component";
import icon from "discourse/helpers/d-icon";
import UppyUpload from "discourse/lib/uppy/uppy-upload";
import { i18n } from "discourse-i18n";

@classNames("watched-words-uploader")
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
    perFileData: () => ({ action_key: this.actionKey }),
    uploadDone: () => {
      this.dialog.alert(i18n("admin.watched_words.form.upload_successful"));
      this.done();
    },
  });

  @alias("uppyUpload.uploading") addDisabled;

  <template>
    <label class="btn btn-default {{if this.addDisabled 'disabled'}}">
      {{icon "upload"}}
      {{i18n "admin.watched_words.form.upload"}}
      <input
        {{didInsert this.uppyUpload.setup}}
        class="hidden-upload-field"
        disabled={{this.addDisabled}}
        type="file"
      />
    </label>
  </template>
}
