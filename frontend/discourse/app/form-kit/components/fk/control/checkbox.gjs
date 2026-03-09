import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import FKLabel from "discourse/form-kit/components/fk/label";
import FKOptional from "discourse/form-kit/components/fk/optional";
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
        <span class="form-kit__control-checkbox-title">
          <span>{{@field.title}}</span>

          {{#if @showRequiredLabel}}
            <span class="form-kit__container-required">({{i18n
                "form_kit.required"
              }})</span>
          {{else}}
            <FKOptional @field={{@field}} />
          {{/if}}
          <FKTooltip @field={{@field}} />
        </span>
        {{#if @hasBlock}}
          <span class="form-kit__control-checkbox-description">{{yield}}</span>
        {{/if}}
      </span>
    </FKLabel>
  </template>
}
