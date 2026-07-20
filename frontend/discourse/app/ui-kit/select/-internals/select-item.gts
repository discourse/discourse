import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import booleanString from "discourse/helpers/boolean-string";
import { or } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import SelectEngine, {
  SelectDescriptor,
  SelectItem as SelectItemModel,
} from "discourse/ui-kit/select/select-engine";

interface SelectItemSignature {
  Args: {
    engine: SelectEngine;
    descriptor: SelectDescriptor;
    multiple?: boolean;
    selectedIcon?: string;
    /**
     * When true, the whole control is disabled/read-only and no option may be activated,
     * regardless of the row's own flag. Closing the overlay on lock is asynchronous (it
     * awaits the exit animation), so an option can stay clickable for that window — the
     * lock has to gate the activation itself, not only the close.
     */
    locked?: boolean;
  };
  Element: HTMLLIElement;
  Blocks: {
    default: [SelectItemModel];
  };
}

/**
 * A single listbox option (`<li role="option">`) inside a `DSelect`. Clicking it
 * routes through the engine's `activate`, which runs an item's `onSelect` callback
 * (an action item) or toggles its selection — so pointer and keyboard share one path
 * (the `dRovingFocus` `onActivate` in `DSelect` simply clicks the active element).
 *
 * The engine owns `aria-selected` (the chosen-value state); the modifier owns the
 * roving highlight via `activeClass`. This part is internal to the select family.
 */
export default class SelectItem extends Component<SelectItemSignature> {
  /**
   * Activates the item unless the control is locked or the row itself is disabled (the
   * modifier already skips disabled items for the keyboard; this guards the pointer path).
   */
  @action
  handleClick(): void {
    if (this.args.locked || this.args.descriptor.flags.disabled) {
      return;
    }
    this.args.engine.activate(this.args.descriptor.item);
  }

  <template>
    <li
      role="option"
      class={{dConcatClass
        "d-combobox__option"
        (if @descriptor.flags.selected "--selected")
        (if @descriptor.flags.__create "--create")
      }}
      aria-selected={{booleanString @descriptor.flags.selected omitFalse=false}}
      aria-disabled={{booleanString @descriptor.flags.disabled}}
      {{on "click" this.handleClick}}
      ...attributes
    >
      {{#if @multiple}}
        {{dIcon
          (or @selectedIcon "check")
          class="d-combobox__option-selected-icon"
        }}
      {{/if}}
      {{yield @descriptor.item}}
    </li>
  </template>
}
