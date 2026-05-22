import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import MiniTagChooser from "discourse/select-kit/components/mini-tag-chooser";

/**
 * Entity picker for `ui.control: "tag-select"`. The current schema
 * convention is a single tag name stored as a string, so we wrap
 * `MiniTagChooser` with `maximum: 1` and unwrap the array it emits
 * into the layout's single-string slot.
 *
 * Matches the pattern in `app/components/tag-settings.gjs` (synonyms
 * field) for FormKit-via-custom integration with select-kit choosers.
 */
export default class InspectorTagField extends Component {
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
    <MiniTagChooser
      @value={{this.value}}
      @onChange={{this.onChange}}
      @options={{hash maximum=1}}
    />
  </template>
}
