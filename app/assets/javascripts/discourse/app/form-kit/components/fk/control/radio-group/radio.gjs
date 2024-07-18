import { on } from "@ember/modifier";
import { eq } from "truth-helpers";
import FKLabel from "discourse/form-kit/components/fk/label";
import uniqueId from "discourse/helpers/unique-id";
import withEventValue from "discourse/helpers/with-event-value";

const FKControlRadioGroupRadio = <template>
  {{#let (uniqueId) as |uuid|}}
    <div class="form-kit__field form-kit__field-radio">
      <FKLabel @fieldId={{uuid}} class="form-kit__control-radio-label">
        <input
          name={{@field.name}}
          type="radio"
          value={{@value}}
          checked={{eq @groupValue @value}}
          id={{uuid}}
          class="form-kit__control-radio"
          disabled={{@field.disabled}}
          ...attributes
          {{on "change" (withEventValue @field.set)}}
        />
        <span>{{yield}}</span>
      </FKLabel>
    </div>
  {{/let}}
</template>;

export default FKControlRadioGroupRadio;
