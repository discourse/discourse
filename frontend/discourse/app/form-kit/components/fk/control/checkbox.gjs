import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { eq } from "truth-helpers";
import FKLabel from "discourse/form-kit/components/fk/label";
import FKOptional from "discourse/form-kit/components/fk/optional";
import FKTooltip from "discourse/form-kit/components/fk/tooltip";

export default class FKControlCheckbox extends Component {
  static controlType = "checkbox";

  @action
  handleInput() {
    this.args.field.set(!this.args.field.value);
  }

  <template>
    <FKLabel class="form-kit__control-checkbox-label">
      <input
        type="checkbox"
        checked={{eq @field.value true}}
        class="form-kit__control-checkbox"
        disabled={{@field.disabled}}
        ...attributes
        {{on "change" this.handleInput}}
      />
      <span class="form-kit__control-checkbox-content">
        <span class="form-kit__control-checkbox-title">
          <span>{{@field.title}}</span>
          <FKOptional @field={{@field}} />
          <FKTooltip @field={{@field}} />
        </span>
        {{#if (has-block)}}
          <span class="form-kit__control-checkbox-description">{{yield}}</span>
        {{/if}}
      </span>
    </FKLabel>
  </template>
}
