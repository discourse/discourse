import { action } from "@ember/object";
import Component from "@ember/component";
import showModal from "discourse/lib/show-modal";

export default class UploadedImageList extends Component {
  @action
  showUploadModal({ value, setting }) {
    showModal("admin-uploaded-image-list", {
      admin: true,
      title: `admin.site_settings.${setting.setting}.title`,
      model: { value, setting },
    }).setProperties({
      save: (v) => this.set("value", v),
    });
  }
}
