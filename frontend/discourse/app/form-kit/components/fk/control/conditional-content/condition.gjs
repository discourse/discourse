import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import FKLabel from "discourse/form-kit/components/fk/label";
import { eq } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dUniqueId from "discourse/ui-kit/helpers/d-unique-id";

// A native radio click mutates the DOM, so a rejected change (where
// `activeName` is unchanged) won't reset the one-way `checked` binding on its
// own. Re-assert it when `resyncToken` bumps.
function syncChecked(element, [name, activeName]) {
  element.checked = name === activeName;
}

const FKControlConditionalContentOption = <template>
  {{#let (dUniqueId) as |uuid|}}
    <FKLabel
      @fieldId={{uuid}}
      class={{dConcatClass
        "form-kit__control-radio-label"
        (if @disabled "--disabled")
        (if @locked "--locked")
      }}
    >
      <input
        type="radio"
        id={{uuid}}
        value={{@name}}
        checked={{eq @name @activeName}}
        disabled={{@disabled}}
        class="form-kit__control-radio"
        {{on "change" (fn @setCondition @name)}}
        {{didUpdate syncChecked @name @activeName @resyncToken}}
      />

      <span>{{yield}}</span>
    </FKLabel>
  {{/let}}
</template>;

export default FKControlConditionalContentOption;
