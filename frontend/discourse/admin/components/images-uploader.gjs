/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { tagName } from "@ember-decorators/component";
import icon from "discourse/helpers/d-icon";
import { acceptedImageFormats } from "discourse/lib/uploads";
import UppyUpload from "discourse/lib/uppy/uppy-upload";
import { i18n } from "discourse-i18n";

@tagName("span")
export default class ImagesUploader extends Component {
  @service currentUser;
  @service siteSettings;

  uppyUpload = new UppyUpload(getOwner(this), {
    id: "images-uploader",
    type: "avatar",
    validateUploadedFilesOptions: {
      imagesOnly: true,
    },
    uploadDone: (upload) => {
      this.done(upload);
    },
  });

  get uploadingOrProcessing() {
    return this.uppyUpload.uploading || this.uppyUpload.processing;
  }

  get uploadButtonText() {
    return this.uploadingOrProcessing ? i18n("uploading") : i18n("upload");
  }

  get acceptedFormats() {
    return acceptedImageFormats(this.currentUser?.staff, this.siteSettings);
  }

  <template>
    <label
      class="btn"
      disabled={{this.uploadingOrProcessing}}
      title={{i18n "admin.site_settings.uploaded_image_list.upload.title"}}
    >
      {{icon "far-image"}}&nbsp;{{this.uploadButtonText}}
      <input
        {{didInsert this.uppyUpload.setup}}
        class="hidden-upload-field"
        disabled={{this.uppyUpload.uploading}}
        type="file"
        accept={{this.acceptedFormats}}
        multiple
      />
    </label>
    {{#if this.uploadingOrProcessing}}
      <span>{{i18n "upload_selector.uploading"}}
        {{this.uppyUpload.uploadProgress}}%</span>
    {{/if}}
  </template>
}
