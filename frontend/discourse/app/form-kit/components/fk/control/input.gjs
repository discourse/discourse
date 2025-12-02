import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import concatClass from "discourse/helpers/concat-class";

const SUPPORTED_TYPES = [
  "color",
  "date",
  "datetime-local",
  "email",
  "hidden",
  "month",
  "number",
  "password",
  "range",
  "search",
  "tel",
  "text",
  "time",
  "url",
  "week",
];

export default class FKControlInput extends Component {
  static controlType = "input";

  @tracked isFocused = false;

  constructor(owner, args) {
    super(...arguments);

    if (["checkbox", "radio"].includes(args.type)) {
      throw new Error(
        `input component does not support @type="${args.type}" as there is a dedicated component for this.`
      );
    }

    if (args.type && !SUPPORTED_TYPES.includes(args.type)) {
      throw new Error(
        `input component does not support @type="${
          args.type
        }", must be one of ${SUPPORTED_TYPES.join(", ")}!`
      );
    }
  }

  get type() {
    return this.args.type ?? "text";
  }

  get displayValue() {
    if (this.type === "number" && this.inputValue !== undefined) {
      return this.inputValue;
    }

    return this.args.field.value ?? "";
  }

  @action
  handleFocus() {
    this.isFocused = true;

    if (this.type === "number") {
      this.inputValue = this.args.field.value ?? "";
    }
  }

  @action
  handleBlur() {
    this.isFocused = false;
    this.inputValue = undefined;
  }

  @action
  handleInput(event) {
    const rawValue = event.target.value;

    if (this.type === "number") {
      this.inputValue = rawValue;
    }

    const value =
      rawValue === ""
        ? null
        : this.type === "number"
          ? parseFloat(rawValue)
          : rawValue;

    this.args.field.set(value);
  }

  <template>
    <div class="form-kit__control-input-wrapper">
      {{#if @before}}
        <span class="form-kit__before-input">{{@before}}</span>
      {{/if}}

      <input
        type={{this.type}}
        value={{this.displayValue}}
        class={{concatClass
          "form-kit__control-input"
          (if @before "has-prefix")
          (if @after "has-suffix")
        }}
        disabled={{@field.disabled}}
        ...attributes
        {{on "focus" this.handleFocus}}
        {{on "blur" this.handleBlur}}
        {{on "input" this.handleInput}}
      />

      {{#if @after}}
        <span class="form-kit__after-input">{{@after}}</span>
      {{/if}}
    </div>
  </template>
}
