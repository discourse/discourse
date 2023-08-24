import { action } from "@ember/object";
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import UploadedImageListModal from "admin/components/modal/uploaded-image-list";

export default class UploadedImageList extends Component {
  @service modal;

  @tracked value;

  @action
  showUploadModal({ value, setting }) {
    console.log(setting);
    this.modal.show(UploadedImageListModal, {
      model: {
        title: `admin.site_settings.${setting.setting}.title`,
        save: this.valueChanged,
        value,
      },
    });
  }

  @action
  valueChanged(value) {
    this.value = value;
  }
}
