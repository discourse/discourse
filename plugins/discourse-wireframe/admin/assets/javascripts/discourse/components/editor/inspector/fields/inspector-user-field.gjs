import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import UserChooser from "discourse/select-kit/components/user-chooser";

/**
 * Entity picker for `ui.control: "user-select"`. No starter block uses
 * this today, but the schema validator accepts it, so the inspector
 * shouldn't fall back to a plain text input. Single-username flavour:
 * UserChooser emits an array, we unwrap to one string.
 */
export default class InspectorUserField extends Component {
  get value() {
    const raw = this.args.custom.value;
    if (typeof raw === "string" && raw.length) {
      return [raw];
    }
    return [];
  }

  @action
  onChange(value) {
    const first = (value || [])[0] ?? "";
    this.args.custom.set(first);
  }

  <template>
    <UserChooser
      @value={{this.value}}
      @onChange={{this.onChange}}
      @options={{hash maximum=1}}
    />
  </template>
}
