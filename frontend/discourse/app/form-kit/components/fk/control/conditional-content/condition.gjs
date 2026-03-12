import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import FKLabel from "discourse/form-kit/components/fk/label";
import { eq } from "discourse/truth-helpers";
import concatClass from "discourse/ui-kit/helpers/d-concat-class";
import uniqueId from "discourse/ui-kit/helpers/d-unique-id";

const FKControlConditionalContentOption = <template>
  {{#let (uniqueId) as |uuid|}}
    <FKLabel
      @fieldId={{uuid}}
      class={{concatClass
        "form-kit__control-radio-label"
        (if @disabled "--disabled")
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
      />

      <span>{{yield}}</span>
    </FKLabel>
  {{/let}}
</template>;

export default FKControlConditionalContentOption;
