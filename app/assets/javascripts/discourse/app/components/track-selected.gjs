import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";

export default class TrackSelected extends Component {
  @action
  onToggle(e) {
    if (e.target.checked) {
      this.args.selectedList.addObject(this.args.selectedId);
    } else {
      this.args.selectedList.removeObject(this.args.selectedId);
    }
  }

  <template>
    <span class={{@class}} ...attributes>
      <input {{on "input" this.onToggle}} type="checkbox" />
    </span>
  </template>
}
