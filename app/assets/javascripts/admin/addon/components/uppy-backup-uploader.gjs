import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import UppyUpload from "discourse/lib/uppy/uppy-upload";
import { i18n } from "discourse-i18n";

export default class UppyBackupUploader extends Component {
  @service siteSettings;

  uppyUpload = new UppyUpload(getOwner(this), {
    id: "uppy-backup-uploader",
    type: "backup",
    uploadRootPath: "/admin/backups",
    uploadUrl: "/admin/backups/upload",

    // local backups
    useChunkedUploads: this.args.localBackupStorage,

    // direct s3 backups
    useMultipartUploadsIfAvailable:
      !this.args.localBackupStorage &&
      this.siteSettings.enable_direct_s3_uploads,

    validateUploadedFilesOptions: { skipValidation: true },

    uploadDone: (responseData) => {
      this.args.done(responseData.file_name);
    },
  });

  get uploadButtonText() {
    return this.uppyUpload.uploading
      ? i18n("admin.backups.upload.uploading_progress", {
          progress: this.uppyUpload.uploadProgress,
        })
      : i18n("admin.backups.upload.label");
  }

  <template>
    <span>
      <label
        class="btn btn-small btn-primary admin-backups-upload"
        disabled={{this.uppyUpload.uploading}}
        title={{i18n "admin.backups.upload.title"}}
        ...attributes
      >
        {{this.uploadButtonText}}
        <input
          {{didInsert this.uppyUpload.setup}}
          class="hidden-upload-field"
          disabled={{this.uppyUpload.uploading}}
          type="file"
          accept=".gz"
        />
      </label>
    </span>
  </template>
}
