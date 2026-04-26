import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import { isSettingValueTrue } from "discourse/admin/models/site-setting";

export default class Bool extends Component {
  get enabled() {
    return isSettingValueTrue(this.args.value);
  }

  @action
  onToggle(event) {
    if (event.target.checked) {
      this.args.changeValueCallback("true");
    } else {
      this.args.changeValueCallback("false");
    }
  }

  <template>
    <label class="checkbox-label">
      <input
        {{on "input" this.onToggle}}
        type="checkbox"
        checked={{this.enabled}}
        disabled={{@disabled}}
      />
      <span>{{trustHTML @setting.description}}</span>
    </label>
  </template>
}
