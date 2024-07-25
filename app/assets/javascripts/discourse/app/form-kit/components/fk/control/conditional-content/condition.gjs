import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { eq } from "truth-helpers";
import FKLabel from "discourse/form-kit/components/fk/label";
import uniqueId from "discourse/helpers/unique-id";

const FKControlConditionalContentOption = <template>
  {{#let (uniqueId) as |uuid|}}
    <FKLabel @fieldId={{uuid}} class="form-kit__control-radio-label">
      <input
        type="radio"
        id={{uuid}}
        value={{@name}}
        checked={{eq @name @activeName}}
        class="form-kit__control-radio"
        {{on "change" (fn @setCondition @name)}}
      />

      <span>{{yield}}</span>
    </FKLabel>
  {{/let}}
</template>;

export default FKControlConditionalContentOption;
