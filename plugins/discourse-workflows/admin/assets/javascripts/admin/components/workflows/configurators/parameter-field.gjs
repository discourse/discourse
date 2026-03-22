import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import { eq } from "discourse/truth-helpers";
import VariableInput from "../variable/input";

function isExpression(value) {
  return typeof value === "string" && value.startsWith("=");
}

export default class ParameterField extends Component {
  @tracked mode = isExpression(this.args.value) ? "expression" : "fixed";

  get expressionValue() {
    const val = this.args.value;
    if (!val || typeof val !== "string") {
      return "";
    }
    return val.startsWith("=") ? val.slice(1) : val;
  }

  get fixedValue() {
    const val = this.args.value;
    if (!val || typeof val !== "string") {
      return val ?? "";
    }
    return val.startsWith("=") ? val.slice(1) : val;
  }

  @action
  toggleMode() {
    const newMode = this.mode === "fixed" ? "expression" : "fixed";
    this.mode = newMode;
    const currentValue = this.args.value || "";

    if (newMode === "expression") {
      const raw =
        typeof currentValue === "string" && currentValue.startsWith("=")
          ? currentValue
          : `=${currentValue}`;
      this.args.onChange(raw);
    } else {
      const raw =
        typeof currentValue === "string" && currentValue.startsWith("=")
          ? currentValue.slice(1)
          : currentValue;
      this.args.onChange(raw);
    }
  }

  @action
  onFixedInput(event) {
    this.args.onChange(event.target.value);
  }

  @action
  onExpressionChange(value) {
    this.args.onChange(`=${value}`);
  }

  <template>
    <div class="workflows-parameter-field">
      {{#unless @noExpression}}
        <DButton
          @action={{this.toggleMode}}
          @translatedLabel="fx"
          class="btn-flat workflows-parameter-field__fx
            {{if (eq this.mode 'expression') '--active'}}"
        />
      {{/unless}}
      <div class="workflows-parameter-field__input">
        {{#if (eq this.mode "expression")}}
          <VariableInput
            @value={{this.expressionValue}}
            @onChange={{this.onExpressionChange}}
          />
        {{else}}
          {{yield this.fixedValue this.onFixedInput}}
        {{/if}}
      </div>
    </div>
  </template>
}
