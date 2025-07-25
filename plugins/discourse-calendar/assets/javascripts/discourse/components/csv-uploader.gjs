import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { or } from "truth-helpers";
import icon from "discourse/helpers/d-icon";
import UppyUpload from "discourse/lib/uppy/uppy-upload";
import { i18n } from "discourse-i18n";

export default class CsvUploader extends Component {
  @service dialog;

  uppyUpload = new UppyUpload(getOwner(this), {
    type: "csv",
    id: "discourse-post-event-csv-uploader",
    autoStartUploads: false,
    uploadUrl: this.args.uploadUrl,
    uppyReady: () => {
      this.uppyUpload.uppyWrapper.uppyInstance.on("file-added", () => {
        this.dialog.confirm({
          message: i18n(`${this.args.i18nPrefix}.confirmation_message`),
          didConfirm: () => this.uppyUpload.startUpload(),
          didCancel: () => this.uppyUpload.reset(),
        });
      });
    },
    uploadDone: () => {
      this.dialog.alert(i18n(`${this.args.i18nPrefix}.success`));
    },
    validateUploadedFilesOptions: {
      csvOnly: true,
    },
  });

  get uploadButtonText() {
    return this.uppyUpload.uploading
      ? i18n("uploading")
      : i18n(`${this.args.i18nPrefix}.text`);
  }

  get uploadButtonDisabled() {
    // https://github.com/emberjs/ember.js/issues/10976#issuecomment-132417731
    return this.uppyUpload.uploading || this.uppyUpload.processing || null;
  }

  <template>
    <span>
      <label class="btn" disabled={{this.uploadButtonDisabled}}>
        {{icon "upload"}}&nbsp;{{this.uploadButtonText}}
        <input
          {{didInsert this.uppyUpload.setup}}
          class="hidden-upload-field"
          disabled={{this.uppyUpload.uploading}}
          type="file"
          accept=".csv"
        />
      </label>
      {{#if (or this.uppyUpload.uploading this.uppyUpload.processing)}}
        <span>{{i18n "upload_selector.uploading"}}
          {{this.uppyUpload.uploadProgress}}%</span>
      {{/if}}
    </span>
  </template>
}
