import Component from "@glimmer/component";
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

  @action
  handleInput(event) {
    const value =
      event.target.value === ""
        ? undefined
        : this.type === "number"
        ? parseFloat(event.target.value)
        : event.target.value;

    this.args.field.set(value);
  }

  <template>
    <div class="form-kit__control-input-wrapper">
      {{#if @before}}
        <span class="form-kit__before-input">{{@before}}</span>
      {{/if}}

      <input
        type={{this.type}}
        value={{@field.value}}
        class={{concatClass
          "form-kit__control-input"
          (if @before "has-prefix")
          (if @after "has-suffix")
        }}
        disabled={{@field.disabled}}
        ...attributes
        {{on "input" this.handleInput}}
      />

      {{#if @after}}
        <span class="form-kit__after-input">{{@after}}</span>
      {{/if}}
    </div>
  </template>
}
