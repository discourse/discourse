import Component from "@ember/component";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
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

  <template>
    <DButton
      @label="admin.site_settings.uploaded_image_list.label"
      @action={{fn
        this.showUploadModal
        (hash value=this.value setting=this.setting)
      }}
    />
  </template>
}
