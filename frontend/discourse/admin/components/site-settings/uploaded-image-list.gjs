/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { tagName } from "@ember-decorators/component";
import DButton from "discourse/ui-kit/d-button";

@tagName("")
export default class UploadedImageList extends Component {
  @service modal;

  @action
  showUploadModal({ value, setting }) {
    this.modal.show(
      () => import("discourse/admin/components/modal/uploaded-image-list"),
      {
        model: {
          title: `admin.site_settings.${setting.setting}.title`,
          changeValue: (v) => this.set("value", v),
          value,
        },
      }
    );
  }

  <template>
    <div ...attributes>
      <DButton
        @action={{fn
          this.showUploadModal
          (hash value=this.value setting=this.setting)
        }}
        @disabled={{@disabled}}
        @label="admin.site_settings.uploaded_image_list.label"
      />
    </div>
  </template>
}
