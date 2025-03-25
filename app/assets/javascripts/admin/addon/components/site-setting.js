import { cached, tracked } from "@glimmer/tracking";
import Component from "@ember/component";
import { dependentKeyCompat } from "@ember/object/compat";
import { readOnly } from "@ember/object/computed";
import BufferedProxy from "ember-buffered-proxy/proxy";
import SettingComponent from "admin/mixins/setting-component";
import SiteSetting from "admin/models/site-setting";

export default class SiteSettingComponent extends Component.extend(
  SettingComponent
) {
  @tracked setting = null;
  updateExistingUsers = null;

  @readOnly("setting.staffLogFilter") staffLogFilter;

  @cached
  @dependentKeyCompat
  get buffered() {
    return BufferedProxy.create({
      content: this.setting,
    });
  }

  _save() {
    const setting = this.buffered;
    return SiteSetting.update(setting.get("setting"), setting.get("value"), {
      updateExistingUsers: this.updateExistingUsers,
    });
  }
}
