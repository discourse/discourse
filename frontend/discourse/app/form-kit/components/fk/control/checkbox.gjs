import { on } from "@ember/modifier";
import { action } from "@ember/object";
import FKBaseControl from "discourse/form-kit/components/fk/control/base";
import FKLabel from "discourse/form-kit/components/fk/label";
import FKRequired from "discourse/form-kit/components/fk/required";
import FKTooltip from "discourse/form-kit/components/fk/tooltip";
import { eq, or } from "discourse/truth-helpers";

export default class FKControlCheckbox extends FKBaseControl {
  static controlType = "checkbox";

  @action
  handleInput(event) {
    this.args.field.set(event.target.checked);
  }

  <template>
    <FKLabel class="form-kit__control-checkbox-label">
      <input
        type="checkbox"
        checked={{or (eq @field.value true) (eq @field.value "true")}}
        class="form-kit__control-checkbox"
        disabled={{@field.disabled}}
        id={{@field.id}}
        name={{@field.name}}
        aria-invalid={{if @field.error "true"}}
        aria-describedby={{if @field.error @field.errorId}}
        ...attributes
        {{on "change" this.handleInput}}
      />
      <span class="form-kit__control-checkbox-content">
        <span class="form-kit__control-checkbox-title-container">
          <span class="form-kit__control-checkbox-title">
            {{#if @label}}
              {{@label}}
            {{else}}
              {{or @title @field.title}}
            {{/if}}
          </span>

          {{#if @field.required}}
            <FKRequired @field={{@field}} />
          {{/if}}
          <FKTooltip @field={{@field}} />
        </span>


        {{#if (has-block)}}
          <span class="form-kit__control-checkbox-description">{{yield}}</span>
        {{/if}}
      </span>
    </FKLabel>
  </template>
}
