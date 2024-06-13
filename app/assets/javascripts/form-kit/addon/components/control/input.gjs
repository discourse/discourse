import Component from "@glimmer/component";
import { assert } from "@ember/debug";
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

    assert(
      `input component does not support @type="${args.type}" as there is a dedicated component for this. Please use the \`field.${args.type}\` instead!`,
      args.type === undefined || !["checkbox", "radio"].includes(args.type)
    );

    assert(
      `input component does not support @type="${
        args.type
      }", must be one of ${SUPPORTED_TYPES.join(", ")}!`,
      args.type === undefined || SUPPORTED_TYPES.includes(args.type)
    );
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

    if (this.args.onSet) {
      this.args.onSet(value, { set: this.args.set });
    } else {
      this.args.setValue(value);
    }
  }

  <template>
    <input
      type={{this.type}}
      value={{@value}}
      class="form-kit__control-input"
      disabled={{@disabled}}
      ...attributes
      {{on "input" this.handleInput}}
    />
  </template>
}
