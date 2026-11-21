import { on } from "@ember/modifier";
import { action } from "@ember/object";
import FKBaseControl from "discourse/form-kit/components/fk/control/base";
import FKLabel from "discourse/form-kit/components/fk/label";
import FKRequired from "discourse/form-kit/components/fk/required";
import FKTooltip from "discourse/form-kit/components/fk/tooltip";
import dIcon from "discourse/ui-kit/helpers/d-icon";

export const CheckboxInput = <template>
  <FKLabel class="form-kit__control-checkbox-label">
    <input class="form-kit__control-checkbox" type="checkbox" ...attributes />
    <span class="form-kit__control-checkbox-checkmark">{{dIcon "check"}}</span>
    <span class="form-kit__control-checkbox-content">{{yield}}</span>
  </FKLabel>
</template>;

export default class FKControlCheckbox extends FKBaseControl {
  static controlType = "checkbox";

  @action
  handleInput(event) {
    this.args.field.set(event.target.checked);
  }

  <template>
    <CheckboxInput
      aria-describedby={{@field.describedBy}}
      aria-invalid={{if @field.error "true"}}
      checked={{or (eq @field.value true) (eq @field.value "true")}}
      disabled={{@field.disabled}}
      id={{@field.id}}
      name={{@field.name}}
      ...attributes
      {{on "change" this.handleInput}}
    >
      {{#if @field.showControlTitle}}
        <span class="form-kit__control-checkbox-title">
          <span>{{or @title @field.title}}</span>

          {{#if @field.required}}
            <FKRequired @field={{@field}} />
          {{/if}}
          <FKTooltip @field={{@field}} />
        </span>
      {{/if}}
      <span class="form-kit__control-checkbox-description">{{yield}}</span>
    </CheckboxInput>
  </template>
}
