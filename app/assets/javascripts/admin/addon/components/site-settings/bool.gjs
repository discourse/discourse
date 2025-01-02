import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action, computed } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { isEmpty } from "@ember/utils";

export default class Bool extends Component {
  @computed("value")
  get enabled() {
    if (isEmpty(this.args.value)) {
      return false;
    }
    return this.args.value.toString() === "true";
  }

  set enabled(value) {
    this.args.changeValueCallback(value ? "true" : "false");
  }

  @action
  onToggle(event) {
    if (event.target.checked) {
      this.enabled = true;
    } else {
      this.enabled = false;
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
