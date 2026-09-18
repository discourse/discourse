import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import UploadedImageListModal from "discourse/admin/components/modal/uploaded-image-list";
import DButton from "discourse/ui-kit/d-button";

export default class UploadedImageList extends Component {
  @service modal;

  @action
  showUploadModal({ value, setting }) {
    this.modal.show(UploadedImageListModal, {
      model: {
        title: `admin.site_settings.${setting.setting}.title`,
        changeValue: (v) => this.args.changeValueCallback(v),
        value,
      },
    });
  }

  <template>
    <div ...attributes>
      <DButton
        @action={{fn this.showUploadModal (hash value=@value setting=@setting)}}
        @disabled={{@disabled}}
        @label="admin.site_settings.uploaded_image_list.label"
      />
    </div>
  </template>
}
