import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import dRovingFocus from "discourse/ui-kit/modifiers/d-roving-focus";
import { i18n } from "discourse-i18n";

const OPTIONS = [
  { id: "apple", count: 12 },
  { id: "apricot", count: 3 },
  { id: "banana", count: 47 },
  { id: "blackberry", count: 8 },
  { id: "cherry", count: 21 },
  { id: "coconut", count: 5 },
];

/**
 * The APG listbox pattern, and the only example here that types.
 *
 * The labels share initials on purpose, so one character lands on the first of a group and a
 * second character picks within it.
 *
 * Matching is on the accessible name rather than on the text. Each row carries a decorative
 * count that belongs to its text but not to its name, so the difference between matching one
 * and matching the other is visible rather than asserted: typing a digit finds nothing.
 *
 * Entry restores the chosen row, which is the listbox convention and the opposite of the
 * toolbar's. Selection is moved by activation rather than by the cursor, so arrowing through
 * the list reads each option without committing to it.
 */
export default class RovingFocusListboxExample extends Component {
  @tracked selected = "banana";

  get rows() {
    return OPTIONS.map((option) => ({
      ...option,
      label: i18n(`styleguide.sections.roving_focus.listbox.${option.id}`),
      selected: this.selected === option.id ? "true" : "false",
    }));
  }

  @action
  select(item) {
    this.selected = item.dataset.optionId;
  }

  <template>
    <ul
      class="roving-demo__listbox"
      role="listbox"
      aria-label={{i18n "styleguide.sections.roving_focus.listbox.label"}}
      {{dRovingFocus
        orientation="vertical"
        itemSelector=".roving-demo__option"
        entryFocus="selected-or-first"
        typeAhead=true
        onActivate=this.select
      }}
    >
      {{#each this.rows key="id" as |row|}}
        <li
          class="roving-demo__option"
          role="option"
          data-option-id={{row.id}}
          aria-selected={{row.selected}}
        >
          {{row.label}}
          {{! Decorative, so it is excluded from the accessible name. Typing a digit therefore
            matches nothing, while the label still matches. }}
          <span
            class="roving-demo__count"
            aria-hidden="true"
          >{{row.count}}</span>
        </li>
      {{/each}}
    </ul>
  </template>
}
