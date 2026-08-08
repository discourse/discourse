import type { TemplateOnlyComponent } from "@ember/component/template-only";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import {
  type SelectItem,
  selectItemLabel,
} from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

interface SelectionLabelSignature {
  Args: {
    item: SelectItem;
    labelField?: string;
  };
}

/**
 * The default presentation for a selected item's label. A held value that could not be
 * resolved (`__unresolved`) renders a warning icon plus the value itself — muted, with an
 * "unavailable" tooltip — so distinct unresolved ids stay distinguishable rather than
 * collapsing into one generic string. Consumers with a `:selection` block bypass this and
 * render the raw item themselves.
 *
 * The state is carried in text, not just the icon and tooltip: focus sits on the enclosing
 * trigger button (or chip), so a `title` on this inner span is never announced, and the icon
 * is `aria-hidden`. Without the visually-hidden text a screen reader would read the bare
 * value as though it resolved fine.
 */
const SelectionLabel: TemplateOnlyComponent<SelectionLabelSignature> =
  <template>
    {{#if @item.__unresolved}}
      <span class="d-combobox__unresolved" title={{i18n "d_select.unresolved"}}>
        {{dIcon "triangle-exclamation"}}
        {{selectItemLabel @item @labelField}}
        <span class="sr-only">{{i18n "d_select.unresolved"}}</span>
      </span>
    {{else}}
      {{selectItemLabel @item @labelField}}
    {{/if}}
  </template>;

export default SelectionLabel;
