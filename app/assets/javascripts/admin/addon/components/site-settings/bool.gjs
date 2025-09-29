import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { isEmpty } from "@ember/utils";

export default class Bool extends Component {
  get enabled() {
    return isEmpty(this.args.value)
      ? false
      : this.args.value.toString() === "true";
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
      <span>{{htmlSafe @setting.description}}</span>
    </label>
  </template>
}
