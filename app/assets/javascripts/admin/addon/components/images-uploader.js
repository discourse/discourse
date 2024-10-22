import Component from "@ember/component";
import { getOwner } from "@ember/owner";
import { tagName } from "@ember-decorators/component";
import UppyUpload from "discourse/lib/uppy/uppy-upload";
import I18n from "discourse-i18n";

@tagName("span")
export default class ImagesUploader extends Component {
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

  get uploadButtonText() {
    return this.uppyUpload.uploading || this.uppyUpload.processing
      ? I18n.t("uploading")
      : I18n.t("upload");
  }
}
