import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { type ComponentLike } from "@glint/template";
import GroupChooserUntyped from "discourse/select-kit/components/group-chooser";

interface InspectorGroupFieldSignature {
  /** FormKit field state for the group picker. */
  Args: {
    /** FormKit field data read and updated by the picker. */
    custom: {
      /** Current FormKit field value. */
      value: unknown;
      /** Writes the selected group name. */
      set: (
        /** Selected group name, or an empty string to clear it. */
        value: string
      ) => void;
    };
  };
}

// TODO(devxp-typescript-pending): drop once GroupChooser has a real Signature.
const GroupChooser = GroupChooserUntyped as unknown as ComponentLike<{
  /** Selected groups, change callback, and select-kit options. */
  Args: {
    /** Called with the selected group names. */
    onChange: (
      /** Selected group names. */
      value: string[]
    ) => void;
    /** Select-kit configuration. */
    options: {
      /** Maximum number of selectable groups. */
      maximum: number;
    };
    /** Selected group names. */
    selected: string[];
  };
}>;

/**
 * Entity picker for `ui.control: "group-select"`. Single-group
 * flavour: GroupChooser emits an array, we unwrap to one string.
 * No starter block uses this today; wired in for completeness so the
 * inspector doesn't fall back to plain text when a future block opts
 * into the control.
 */
export default class InspectorGroupField extends Component<InspectorGroupFieldSignature> {
  /** Selected group names in the chooser's array format. */
  get value(): string[] {
    const raw = this.args.custom.value;
    if (typeof raw === "string" && raw.length) {
      return [raw];
    }
    return [];
  }

  /**
   * Commits the first selected group name.
   *
   * @param value - Selected group names from the chooser.
   */
  @action
  onChange(value: string[]): void {
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
