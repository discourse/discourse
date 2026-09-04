import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { type ComponentLike } from "@glint/template";
import MiniTagChooserUntyped from "discourse/select-kit/components/mini-tag-chooser";

interface InspectorTagFieldSignature {
  /** FormKit field state for the tag picker. */
  Args: {
    /** FormKit field data read and updated by the picker. */
    custom: {
      /** Current FormKit field value. */
      value: unknown;
      /** Writes the selected tag name. */
      set: (
        /** Selected tag name, or an empty string to clear it. */
        value: string
      ) => void;
    };
  };
}

// TODO(devxp-typescript-pending): drop once MiniTagChooser has a real Signature.
const MiniTagChooser = MiniTagChooserUntyped as unknown as ComponentLike<{
  /** Selected tags, change callback, and select-kit options. */
  Args: {
    /** Called with the selected tag names. */
    onChange: (
      /** Selected tag names. */
      value: string[]
    ) => void;
    /** Select-kit configuration. */
    options: {
      /** Maximum number of selectable tags. */
      maximum: number;
    };
    /** Selected tag names. */
    value: string[];
  };
}>;

/**
 * Entity picker for `ui.control: "tag-select"`. The current schema
 * convention is a single tag name stored as a string, so we wrap
 * `MiniTagChooser` with `maximum: 1` and unwrap the array it emits
 * into the layout's single-string slot.
 *
 * Matches the pattern in `app/components/tag-settings.gjs` (synonyms
 * field) for FormKit-via-custom integration with select-kit choosers.
 */
export default class InspectorTagField extends Component<InspectorTagFieldSignature> {
  /** Selected tag names in the chooser's array format. */
  get value(): string[] {
    const raw = this.args.custom.value;
    if (typeof raw === "string" && raw.length) {
      return [raw];
    }
    return [];
  }

  /**
   * Commits the first selected tag name.
   *
   * @param value - Selected tag names from the chooser.
   */
  @action
  onChange(value: string[]): void {
    const first = (value || [])[0] ?? "";
    this.args.custom.set(first);
  }

  <template>
    <MiniTagChooser
      @value={{this.value}}
      @onChange={{this.onChange}}
      @options={{hash maximum=1}}
    />
  </template>
}
