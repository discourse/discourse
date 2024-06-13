import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import FKLabel from "form-kit/components/label";
import { eq } from "truth-helpers";
import uniqueId from "discourse/helpers/unique-id";

const FKControlConditionalContentOption = <template>
  {{#let (uniqueId) as |uuid|}}
    <FKLabel @fieldId={{uuid}} class="form-kit__control-radio-label">
      <input
        type="radio"
        id={{uuid}}
        value={{@name}}
        checked={{eq @name @activeName}}
        {{on "change" (fn @setCondition @name)}}
      />

      {{yield}}
    </FKLabel>
  {{/let}}
</template>;

export default FKControlConditionalContentOption;
