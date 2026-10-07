import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import dRovingFocus from "discourse/ui-kit/modifiers/d-roving-focus";
import { i18n } from "discourse-i18n";

const OPTIONS = ["keyboard", "contrast", "captions", "motion", "labels"];

/**
 * Mirrors https://www.w3.org/WAI/ARIA/apg/patterns/listbox/ in its multi-select form.
 *
 * Entry lands on the first chosen row, which is what the pattern asks for: if one or more
 * options are selected before the listbox receives focus, focus is set on the first selected
 * one. The reader is returned to their own selection rather than to the top. The first option
 * is chosen on purpose so that is visible.
 *
 * This accepts a hazard knowingly, because the pattern does. Space toggles the focused option,
 * so starting on a chosen one means the next Space removes it. A combobox popup, where a cursor
 * is seeded automatically and Enter reads as "take this", has better reason to avoid that and
 * can, but a listbox the reader tabbed into deliberately and can see is not that case.
 *
 * Wrapping is on, so passing the last row returns to the first instead of stopping. A list this
 * short makes that worth having; a very long one usually does not, which is why it is a choice
 * rather than a default.
 */
export default class RovingFocusMultiSelectExample extends Component {
  @tracked chosen = ["keyboard"];

  get rows() {
    return OPTIONS.map((id) => ({
      id,
      label: i18n(`styleguide.sections.roving_focus.multi.${id}`),
      selected: this.chosen.includes(id) ? "true" : "false",
    }));
  }

  @action
  toggle(item) {
    const id = item.dataset.optionId;
    this.chosen = this.chosen.includes(id)
      ? this.chosen.filter((chosen) => chosen !== id)
      : [...this.chosen, id];
  }

  <template>
    <ul
      aria-label={{i18n "styleguide.sections.roving_focus.multi.label"}}
      aria-multiselectable="true"
      class="roving-demo__listbox"
      role="listbox"
      {{dRovingFocus
        orientation="vertical"
        itemSelector=".roving-demo__option"
        entryFocus="selected-or-first"
        wrap=true
        onActivate=this.toggle
      }}
    >
      {{#each this.rows key="id" as |row|}}
        <li
          aria-selected={{row.selected}}
          class="roving-demo__option"
          data-option-id={{row.id}}
          role="option"
        >
          {{row.label}}
        </li>
      {{/each}}
    </ul>
  </template>
}
