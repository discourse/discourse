/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { tagName } from "@ember-decorators/component";
import UploadedImageListModal from "discourse/admin/components/modal/uploaded-image-list";
import DButton from "discourse/components/d-button";

@tagName("")
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
    <div ...attributes>
      <DButton
        @label="admin.site_settings.uploaded_image_list.label"
        @action={{fn
          this.showUploadModal
          (hash value=this.value setting=this.setting)
        }}
        @disabled={{@disabled}}
      />
    </div>
  </template>
}
