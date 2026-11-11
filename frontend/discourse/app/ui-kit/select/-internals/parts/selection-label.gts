import type { TemplateOnlyComponent } from "@ember/component/template-only";
import SelectEngine, {
  SelectRecord,
} from "discourse/ui-kit/select/select-engine";

interface SelectionLabelSignature {
  Args: {
    record: SelectRecord;
    engine: SelectEngine;
  };
}

/**
 * The default presentation for a selected item's label. The text comes from
 * `SelectEngine#getSelectionLabel`, the same rule behind the typeahead input, the trigger's
 * accessible name and announcements, so every surface and every screen reader path says the
 * same words. An unresolved item reads as "Unknown item (id)" unless a consumer named it.
 *
 * The visible text is the whole message on purpose: no icon, tooltip or screen-reader-only
 * text adds to it, because a `title` on this inner span is never announced (focus sits on the
 * enclosing trigger or chip) and hidden text would tell screen readers something sighted
 * users never see. Consumers with a `:selection` block bypass this and render the raw item.
 */
const SelectionLabel: TemplateOnlyComponent<SelectionLabelSignature> =
  <template>
    {{#if @record.__unresolved}}
      <span class="d-select__unresolved">
        {{~@engine.getSelectionLabel @record~}}
      </span>
    {{else}}
      {{@engine.getSelectionLabel @record}}
    {{/if}}
  </template>;

export default SelectionLabel;
