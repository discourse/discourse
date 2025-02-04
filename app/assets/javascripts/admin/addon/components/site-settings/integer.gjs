import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";

export default class SiteSettingsInteger extends Component {
  @action
  updateValue(event) {
    const num = parseInt(event.target.value, 10);

    if (isNaN(num)) {
      return;
    }

    // Settings are stored as strings, this way the main site setting component
    // doesn't get confused and think the value has changed from default if the
    // admin sets it to the same number as the default.
    this.args.changeValueCallback(num.toString());
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
  </template>
}
