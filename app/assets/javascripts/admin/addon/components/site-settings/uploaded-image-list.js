import Component from "@ember/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import UploadedImageListModal from "admin/components/modal/uploaded-image-list";

export default class UploadedImageList extends Component {
  @service modal;

  @action
  showUploadModal({ value, setting }) {
    this.modal.show(UploadedImageListModal, {
      model: {
        title: `admin.site_settings.${setting.setting}.title`,
        changeValue: (v) => this.set("value", v),
        value,
      },
    });
  }
}
