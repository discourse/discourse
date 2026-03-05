import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import FKLabel from "discourse/form-kit/components/fk/label";
import FKRequired from "discourse/form-kit/components/fk/required";
import FKTooltip from "discourse/form-kit/components/fk/tooltip";
import { eq, or } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class FKControlCheckbox extends Component {
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
        ...attributes
        {{on "change" this.handleInput}}
      />
      <span class="form-kit__control-checkbox-content">
        <span class="form-kit__control-checkbox-title-container">
          <span class="form-kit__control-checkbox-title">
            {{#if @label}}
              {{@label}}
            {{else}}
              {{@field.title}}
            {{/if}}
          </span>

          <FKRequired @field={{@field}} />
          <FKTooltip @field={{@field}} />
        </span>

        {{#if (has-block)}}
          <span class="form-kit__control-checkbox-description">{{yield}}</span>
        {{/if}}
      </span>
    </FKLabel>
  </template>
}
