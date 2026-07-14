import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import GroupChooser from "discourse/select-kit/components/group-chooser";

/**
 * Entity picker for `ui.control: "group-select"`. Single-group
 * flavour: GroupChooser emits an array, we unwrap to one string.
 * No starter block uses this today; wired in for completeness so the
 * inspector doesn't fall back to plain text when a future block opts
 * into the control.
 */
export default class InspectorGroupField extends Component {
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
    <GroupChooser
      @selected={{this.value}}
      @onChange={{this.onChange}}
      @options={{hash maximum=1}}
    />
  </template>
}
