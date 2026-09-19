import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import FKLabel from "discourse/form-kit/components/fk/label";
import withEventValue from "discourse/helpers/with-event-value";
import { eq } from "discourse/truth-helpers";
import dUniqueId from "discourse/ui-kit/helpers/d-unique-id";

const radioTitle = <template>
  <span class="form-kit__control-radio-title">{{yield}}</span>
</template>;

const radioDescription = <template>
  <span class="form-kit__control-radio-description">{{yield}}</span>
</template>;

const FKControlRadioGroupRadio = <template>
  {{#let (dUniqueId) as |uuid|}}
    <div class="form-kit__field form-kit__field-radio">
      <FKLabel class="form-kit__control-radio-label" @fieldId={{uuid}}>
        <input
          checked={{eq @field.value @value}}
          class="form-kit__control-radio"
          disabled={{@field.disabled}}
          id={{uuid}}
          name={{@field.name}}
          type="radio"
          value={{@value}}
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
