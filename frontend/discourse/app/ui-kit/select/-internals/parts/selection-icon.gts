import type { TemplateOnlyComponent } from "@ember/component/template-only";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import SelectEngine, {
  SelectRecord,
} from "discourse/ui-kit/select/select-engine";

interface SelectionIconSignature {
  Args: {
    /** The held record whose item's icon is drawn. */
    record: SelectRecord;
    engine: SelectEngine;
  };
}

/**
 * A held item's icon, drawn before its label or selection block. It is decorative: the label
 * beside it names the value.
 */
const SelectionIcon: TemplateOnlyComponent<SelectionIconSignature> = <template>
  {{#let (@engine.heldItem @record) as |held|}}
    {{#if held.icon}}
      {{dIcon held.icon class="d-select__selection-icon"}}
    {{/if}}
  {{/let}}
</template>;

export default SelectionIcon;
