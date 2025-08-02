import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { eq } from "truth-helpers";
import FKLabel from "discourse/form-kit/components/fk/label";
import uniqueId from "discourse/helpers/unique-id";
import withEventValue from "discourse/helpers/with-event-value";

const radioTitle = <template>
  <span class="form-kit__control-radio-title">{{yield}}</span>
</template>;

const radioDescription = <template>
  <span class="form-kit__control-radio-description">{{yield}}</span>
</template>;

const FKControlRadioGroupRadio = <template>
  {{#let (uniqueId) as |uuid|}}
    <div class="form-kit__field form-kit__field-radio">
      <FKLabel @fieldId={{uuid}} class="form-kit__control-radio-label">
        <input
          name={{@field.name}}
          type="radio"
          value={{@value}}
          checked={{eq @field.value @value}}
          id={{uuid}}
          class="form-kit__control-radio"
          disabled={{@field.disabled}}
          ...attributes
          {{on "change" (withEventValue @field.set)}}
        />
        <span class="form-kit__control-radio-content">
          {{yield (hash Title=radioTitle Description=radioDescription)}}
        </span>
      </FKLabel>
    </div>
  {{/let}}
</template>;

export default FKControlRadioGroupRadio;
