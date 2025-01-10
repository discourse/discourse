import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { isEmpty } from "@ember/utils";

export default class Bool extends Component {
  @tracked
  enabled = isEmpty(this.args.value)
    ? false
    : this.args.value.toString() === "true";

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
      />
      <span>{{htmlSafe @setting.description}}</span>
    </label>
  </template>
}
