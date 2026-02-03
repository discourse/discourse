import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import FKLabel from "discourse/form-kit/components/fk/label";
import concatClass from "discourse/helpers/concat-class";
import uniqueId from "discourse/helpers/unique-id";
import { eq } from "discourse/truth-helpers";

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
