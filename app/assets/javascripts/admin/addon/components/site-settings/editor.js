import Component from "@glimmer/component";
import { action } from "@ember/object";
import DiscourseURL from "discourse/lib/url";

export default class SiteSettingEditor extends Component {
  @action
  navigateToEditorPage() {
    console.log(
      `/admin/customize/themes/${this.args.model.id}/editor/${this.args.setting.setting}`
    );
    DiscourseURL.routeTo(
      `/admin/customize/themes/${this.args.model.id}/editor/${this.args.setting.setting}`
    );
    // console.log(this.args.model, this.args.setting);
  }
}
