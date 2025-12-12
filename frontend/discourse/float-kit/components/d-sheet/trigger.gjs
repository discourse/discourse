import Component from "@glimmer/component";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";

/**
 * Trigger button for opening a sheet.
 *
 * @component Trigger
 * @param {Object} sheet - The sheet controller instance
 * @param {Function} onPresentedChange - Callback to change presented state (controlled mode)
 * @param {Function} openSheet - Handler to open sheet (uncontrolled mode)
 */
export default class Trigger extends Component {
  @action
  handleClick() {
    if (this.args.onPresentedChange) {
      this.args.onPresentedChange(true);
    } else if (this.args.openSheet) {
      this.args.openSheet();
    } else if (this.args.sheet?.open) {
      this.args.sheet.open();
    }
  }

  <template>
    <DButton @action={{this.handleClick}}>
      {{yield}}
    </DButton>
  </template>
}
