import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import SettingValidationMessage from "admin/components/setting-validation-message";
import SiteSettingDescription from "admin/components/site-settings/description";

export default class SiteSettingsInteger extends Component {
  @action
  updateValue(event) {
    const num = parseInt(event.target.value, 10);

    if (isNaN(num)) {
      return;
    }

    this.args.changeValueCallback(num);
  }

  @action
  preventDecimal(event) {
    if (event.key === "." || event.key === ",") {
      event.preventDefault();
    }
  }

  <template>
    <input
      {{on "keydown" this.preventDecimal}}
      {{on "input" this.updateValue}}
      type="number"
      value={{@value}}
      min={{if @setting.min @setting.min null}}
      max={{if @setting.max @setting.max null}}
      class="input-setting-integer"
      step="1"
    />

    <SettingValidationMessage @message={{@validationMessage}} />
    <SiteSettingDescription @description={{@setting.description}} />
  </template>
}
