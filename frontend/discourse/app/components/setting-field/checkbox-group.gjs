import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { CheckboxInput } from "discourse/form-kit/components/fk/control/checkbox";
import FKFieldset from "discourse/form-kit/components/fk/fieldset";
import includes from "discourse/truth-helpers/helpers/includes";

function updateSelection(field, value, event) {
  const selected = field.value ?? [];
  field.set(
    event.target.checked
      ? [...selected, value]
      : selected.filter((id) => id !== value)
  );
}

export default <template>
  <@field.Control>
    <FKFieldset
      aria-describedby={{@field.describedBy}}
      aria-invalid={{if @field.error "true"}}
      aria-label={{@field.title}}
      class="form-kit__checkbox-group"
      disabled={{@field.disabled}}
      id={{@field.id}}
    >
      {{#each @definition.valid_values key="value" as |choice|}}
        <CheckboxInput
          checked={{includes (or @field.value (array)) choice.value}}
          name={{@field.name}}
          value={{choice.value}}
          {{on "change" (fn updateSelection @field choice.value)}}
        >{{choice.name}}</CheckboxInput>
      {{/each}}
    </FKFieldset>
  </@field.Control>
</template>
