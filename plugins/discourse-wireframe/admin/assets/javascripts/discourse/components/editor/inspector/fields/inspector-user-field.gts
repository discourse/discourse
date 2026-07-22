import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { type ComponentLike } from "@glint/template";
import UserChooserUntyped from "discourse/select-kit/components/user-chooser";

interface InspectorUserFieldSignature {
  /** FormKit field state for the user picker. */
  Args: {
    /** FormKit field data read and updated by the picker. */
    custom: {
      /** Current FormKit field value. */
      value: unknown;
      /** Writes the selected username. */
      set: (
        /** Selected username, or an empty string to clear it. */
        value: string
      ) => void;
    };
  };
}

// TODO(devxp-typescript-pending): drop once UserChooser has a real Signature.
const UserChooser = UserChooserUntyped as unknown as ComponentLike<{
  /** Selected users, change callback, and select-kit options. */
  Args: {
    /** Called with the selected usernames. */
    onChange: (
      /** Selected usernames. */
      value: string[]
    ) => void;
    /** Select-kit configuration. */
    options: {
      /** Maximum number of selectable users. */
      maximum: number;
    };
    /** Selected usernames. */
    value: string[];
  };
}>;

/**
 * Entity picker for `ui.control: "user-select"`. No starter block uses
 * this today, but the schema validator accepts it, so the inspector
 * shouldn't fall back to a plain text input. Single-username flavour:
 * UserChooser emits an array, we unwrap to one string.
 */
export default class InspectorUserField extends Component<InspectorUserFieldSignature> {
  /** Selected usernames in the chooser's array format. */
  get value(): string[] {
    const raw = this.args.custom.value;
    if (typeof raw === "string" && raw.length) {
      return [raw];
    }
    return [];
  }

  /**
   * Commits the first selected username.
   *
   * @param value - Selected usernames from the chooser.
   */
  @action
  onChange(value: string[]): void {
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
