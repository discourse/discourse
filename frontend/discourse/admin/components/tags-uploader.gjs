import Component from "@glimmer/component";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import UppyUpload from "discourse/lib/uppy/uppy-upload";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class TagsUploader extends Component {
  @service dialog;

  uppyUpload = new UppyUpload(getOwner(this), {
    type: "csv",
    id: this.args.id,
    uploadUrl: "/tags/upload",
    uploadDone: this.uploadDone,
    preventDirectS3Uploads: true,
    validateUploadedFilesOptions: { csvOnly: true },
  });

  get addDisabled() {
    return this.uppyUpload.uploading;
  }

  @action
  uploadDone() {
    this.args.closeModal();
    this.args.refresh();
    this.dialog.alert(i18n("tagging.upload_successful"));
  }

  <template>
    <div id="tag-uploader">
      <label
        class={{dConcatClass
          "btn btn-default"
          (if this.addDisabled "disabled")
        }}
      >
        {{dIcon "upload"}}
        {{i18n "admin.watched_words.form.upload"}}
        <input
          {{didInsert this.uppyUpload.setup}}
          class="hidden-upload-field"
          disabled={{this.addDisabled}}
          type="file"
          accept="text/plain,text/csv"
        />
      </label>
      <span class="instructions">{{i18n "tagging.upload_instructions"}}</span>
    </div>
  </template>
}
