import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { LOCALES } from "../../../../../lib/select-fixtures";

/**
 * A panel that owns controls of its own — the `button` variant's filter, plus a footer action —
 * so the whole tab sequence can be walked in one place.
 *
 * The sequence is the point, and it is not the one the DOM would give on its own. The panel is
 * rendered into a portal near the end of the document rather than beside the trigger, so left
 * alone, Tab out of it would land in whatever follows that portal, and nothing would lead into it
 * from the field at all. Both directions are put back, so the panel behaves as if it were sitting
 * inline under the trigger.
 *
 * The list itself is deliberately NOT a stop: its rows are reached with the arrow keys, and a
 * scroll container with no focusable content is kept out of the sequence explicitly, since a
 * browser would otherwise adopt it as a tab stop onto nothing.
 */
export default class TabOrderSelectExample extends Component {
  @tracked value = null;

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-tab-order"
      @variant="button"
      @items={{LOCALES}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @label={{i18n "styleguide.sections.select.tab_order_label"}}
      @placeholder={{i18n "styleguide.sections.select.placeholder"}}
    >
      {{! A way OUT of the picker, not a way to confirm it: a select commits on selection, so a
        footer that looks like it needs pressing teaches the wrong shape.

        The flat button style, because a footer states something rather than competing with the
        list, and because it is the style that already fills when focused by keyboard — which this
        card depends on, since the control is a tab stop a reader has to SEE they have reached. }}
      <:footer as |state|>
        <DButton
          class="btn-flat"
          @action={{state.close}}
          @icon="up-right-from-square"
          @label="styleguide.sections.select.tab_order_footer_action"
        />
      </:footer>
    </DSelect>
  </template>
}
