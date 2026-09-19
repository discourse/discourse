import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import dRovingFocus from "discourse/ui-kit/modifiers/d-roving-focus";
import { i18n } from "discourse-i18n";

const CHOICES = ["left", "center", "right"];

/**
 * Mirrors https://www.w3.org/WAI/ARIA/apg/patterns/radio/
 *
 * The APG radio group pattern, and the one place selection is meant to follow the cursor.
 *
 * A radio group states which member it is checked on with `aria-checked` rather than
 * `aria-selected`, so this is the example that covers that spelling: entry lands on the checked
 * member, not the first, which is what a reader returning to the group expects.
 *
 * Unlike the listbox, moving the cursor also moves the checked state. The practice page treats
 * that as the consumer's call rather than the modifier's, so it is wired here through the
 * callback that reports cursor movement. No activation handler is needed as a result: the
 * member under the cursor is always the checked one, leaving Space nothing to do.
 */
export default class RovingFocusRadioGroupExample extends Component {
  @tracked checked = "center";

  get choices() {
    return CHOICES.map((id) => ({
      id,
      label: i18n(`styleguide.sections.roving_focus.radio.${id}`),
      checked: this.checked === id ? "true" : "false",
    }));
  }

  @action
  check(item) {
    // The null argument is an active-mode signal, so a roving-tabindex group never sees one; the
    // guard keeps the callback honest against its own contract rather than against this group.
    if (item) {
      this.checked = item.dataset.choiceId;
    }
  }

  <template>
    <div
      aria-label={{i18n "styleguide.sections.roving_focus.radio.label"}}
      class="roving-demo__radios"
      role="radiogroup"
      {{dRovingFocus
        itemSelector=".roving-demo__radio"
        entryFocus="selected-or-first"
        onActiveChange=this.check
        wrap=true
      }}
    >
      {{#each this.choices key="id" as |choice|}}
        <span
          aria-checked={{choice.checked}}
          class="roving-demo__radio"
          data-choice-id={{choice.id}}
          role="radio"
        >
          {{choice.label}}
        </span>
      {{/each}}
    </div>
  </template>
}
