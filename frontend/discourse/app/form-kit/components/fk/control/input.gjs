import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import FKBaseControl from "discourse/form-kit/components/fk/control/base";
import { siteDir } from "discourse/lib/text-direction";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

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

export default class FKControlInput extends FKBaseControl {
  static controlType = "input";

  @service siteSettings;

  constructor(owner, args) {
    super(owner, args);

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

    // Legacy path: when @type is not set on <form.Field />,
    // set the specific input type (e.g. "input-number") on the field.
    if (!args.field.hasExplicitType) {
      args.field.type = "input-" + (args.type ?? "text");
    }
  }

  get type() {
    return this.args.type ?? "text";
  }

  get dir() {
    if (!this.siteSettings.support_mixed_text_direction) {
      return;
    }

    return this.args.field.value ? "auto" : siteDir();
  }

  get displayValue() {
    const fieldValue = this.args.field.value;

    if (
      this.type === "number" &&
      this.inputValue !== undefined &&
      Object.is(parseFloat(this.inputValue), parseFloat(fieldValue))
    ) {
      return this.inputValue;
    }

    return fieldValue ?? "";
  }

  @action
  handleFocus() {
    if (this.type === "number") {
      this.inputValue = this.args.field.value ?? "";
    }
  }

  @action
  handleBlur() {
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
        aria-describedby={{@field.describedBy}}
        aria-invalid={{if @field.error "true"}}
        class={{dConcatClass
          "form-kit__control-input"
          (if @before "has-prefix")
          (if @after "has-suffix")
        }}
        dir={{this.dir}}
        disabled={{@field.disabled}}
        id={{@field.id}}
        name={{@field.name}}
        placeholder={{@field.placeholder}}
        type={{this.type}}
        value={{this.displayValue}}
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
