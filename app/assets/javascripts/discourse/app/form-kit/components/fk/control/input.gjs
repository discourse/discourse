import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";

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
    <input
      type={{this.type}}
      value={{@value}}
      class="form-kit__control-input"
      disabled={{@field.disabled}}
      ...attributes
      {{on "input" this.handleInput}}
    />
  </template>
}
