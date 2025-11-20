import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import {
  addUniqueValueToArray,
  removeValueFromArray,
} from "discourse/lib/array-tools";

export default class TrackSelected extends Component {
  @action
  onToggle(e) {
    if (e.target.checked) {
      addUniqueValueToArray(this.args.selectedList, this.args.selectedId);
    } else {
      removeValueFromArray(this.args.selectedList, this.args.selectedId);
    }
  }

  <template>
    <span class={{@class}} ...attributes>
      <input {{on "input" this.onToggle}} type="checkbox" />
    </span>
  </template>
}
