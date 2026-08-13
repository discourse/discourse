import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import dRovingFocus from "discourse/ui-kit/modifiers/d-roving-focus";
import { i18n } from "discourse-i18n";

const OPTIONS = ["daily", "weekly", "monthly", "never"];

/**
 * Mirrors https://www.w3.org/WAI/ARIA/apg/patterns/combobox/
 *
 * The other examples move DOM focus between items. This one does not, and that is the whole
 * point of it: focus stays on the control the reader arrived at, while a virtual cursor moves
 * through the options and the control reports where it is with `aria-activedescendant`.
 *
 * Watch the focus ring while arrowing. It never leaves the button, yet the highlight moves and
 * a screen reader announces each option, because what is announced follows the attribute rather
 * than the focus.
 *
 * The listbox is reachable from the controller through `aria-controls`, which is one of the
 * three relationships the specification permits between a control and the descendant it points
 * at. Pointing across to an unrelated element instead is the mistake the modifier warns about
 * in development, and it is easy to make once a popup is portaled somewhere else in the DOM.
 */
export default class RovingFocusComboboxExample extends Component {
  @tracked controller = null;
  @tracked expanded = false;
  @tracked selected = "weekly";

  get rows() {
    return OPTIONS.map((id) => ({
      id,
      label: i18n(`styleguide.sections.roving_focus.combobox.${id}`),
      selected: this.selected === id ? "true" : "false",
    }));
  }

  get selectedLabel() {
    return i18n(`styleguide.sections.roving_focus.combobox.${this.selected}`);
  }

  @action
  captureController(element) {
    this.controller = element;
  }

  @action
  choose(item) {
    this.selected = item.dataset.optionId;
    this.expanded = false;
  }

  @action
  toggle() {
    this.expanded = !this.expanded;
  }

  <template>
    <div class="roving-demo__combobox">
      <button
        type="button"
        class="roving-demo__combobox-trigger"
        role="combobox"
        aria-expanded={{if this.expanded "true" "false"}}
        aria-controls="roving-demo-combobox-listbox"
        aria-label={{i18n "styleguide.sections.roving_focus.combobox.label"}}
        {{didInsert this.captureController}}
        {{on "click" this.toggle}}
      >{{this.selectedLabel}}</button>

      {{#if this.expanded}}
        <ul
          id="roving-demo-combobox-listbox"
          class="roving-demo__combobox-listbox"
          role="listbox"
          {{dRovingFocus
            focusStrategy="active-descendant"
            controllerElement=this.controller
            itemSelector=".roving-demo__combobox-option"
            activeClass="roving-demo__combobox-option--active"
            entryFocus="selected-or-first"
            onActivate=this.choose
          }}
        >
          {{#each this.rows key="id" as |row|}}
            <li
              class="roving-demo__combobox-option"
              role="option"
              data-option-id={{row.id}}
              aria-selected={{row.selected}}
            >
              {{row.label}}
            </li>
          {{/each}}
        </ul>
      {{/if}}
    </div>
  </template>
}
