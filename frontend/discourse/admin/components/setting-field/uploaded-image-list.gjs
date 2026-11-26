import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import UploadedImageListModal from "discourse/admin/components/modal/uploaded-image-list";
import DButton from "discourse/ui-kit/d-button";

export default class SettingFieldUploadedImageList extends Component {
  @service modal;

  @action
  showUploadModal() {
    this.modal.show(UploadedImageListModal, {
      model: {
        title: `admin.site_settings.${this.args.definition.key}.title`,
        changeValue: this.args.field.set,
        value: this.args.field.value,
      },
    });
  }

  <template>
    <@field.Control>
      <div>
        <DButton
          class="btn-default"
          @action={{this.showUploadModal}}
          @disabled={{@field.disabled}}
          @label="admin.site_settings.uploaded_image_list.label"
        />
      </div>
    </@field.Control>
  </template>
}
