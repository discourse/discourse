import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import booleanString from "discourse/helpers/boolean-string";
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
     * The roving highlight, driven from `DSelect` tracked state rather than the modifier's
     * imperative class, so it is rendered by the template and survives a re-render (the
     * windowed list re-renders rows out from under an out-of-band `classList` mutation).
     */
    active?: boolean;
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
        (if @active "--active")
        (if @descriptor.flags.selected "--selected")
        (if @descriptor.flags.__create "--create")
        (if @descriptor.flags.__none "--none")
      }}
      aria-selected={{booleanString @descriptor.flags.selected omitFalse=false}}
      aria-disabled={{booleanString @descriptor.flags.disabled}}
      {{on "click" this.handleClick}}
      ...attributes
    >
      {{! Both glyphs stay hidden from assistive tech deliberately: an option row takes its
      accessible name from its contents, so a screen-reader-only selected label here would land
      inside every row's name. The row's aria-selected attribute is the state channel.

      A consumer-supplied glyph keeps the show-when-selected behaviour — there is no unselected
      counterpart to pair it with. }}
      {{#if @selectedIcon}}
        {{dIcon @selectedIcon class="d-combobox__option-selected-icon"}}
      {{else if @multiple}}
        {{! The hollow square pair reads as a checkbox, and the solid variant is absent from
        the icon sprite. }}
        {{dIcon
          (if @descriptor.flags.selected "far-square-check" "far-square")
          class="d-combobox__option-selected-icon --checkbox"
        }}
      {{/if}}
      {{yield @descriptor.item}}
    </li>
  </template>
}
