import Component from "@glimmer/component";
import { assert } from "@ember/debug";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import FormMeta from "form-kit/components/form/meta";
import FormText from "form-kit/components/form/text";

const VALID_INPUT_TYPES = [
  // 'button' - not useful as a control component
  // 'checkbox' - handled separately, for handling `checked` correctly and operating with true boolean values
  "color",
  "date",
  "datetime-local",
  "email",
  // 'file' - would need special handling
  "hidden",
  // 'image' - not useful as a control component
  "month",
  "number",
  "password",
  // 'radio' - handled separately, for handling groups or radio buttons
  "range",
  // 'reset' - would need special handling
  "search",
  // 'submit' - not useful as a control component
  "tel",
  "text",
  "time",
  "url",
  "week",
];

export default class FkControlInput extends Component {
  constructor(owner, args) {
    super(...arguments);

    assert(
      `input component does not support @type="${args.type}" as there is a dedicated component for this. Please use the \`field.${args.type}\` instead!`,
      args.type === undefined || !["checkbox", "radio"].includes(args.type)
    );

    assert(
      `input component does not support @type="${
        args.type
      }", must be one of ${VALID_INPUT_TYPES.join(", ")}!`,
      args.type === undefined || VALID_INPUT_TYPES.includes(args.type)
    );
  }

  get type() {
    return this.args.type ?? "text";
  }

  @action
  handleInput(event) {
    this.args.setValue(
      this.type === "number"
        ? parseFloat(event.target.value)
        : event.target.value
    );
  }

  <template>
    {{#if @label}}
      <label class="d-form-input-label" for={{@name}}>
        {{@label}}

        {{#unless @required}}
          <span class="d-form-field__optional">(Optional)</span>
        {{/unless}}
      </label>
    {{/if}}

    {{#if @help}}
      <FormText>{{@help}}</FormText>
    {{/if}}

    <input
      name={{@name}}
      type={{this.type}}
      value={{@value}}
      id={{@fieldId}}
      aria-invalid={{if @invalid "true"}}
      aria-describedby={{if @invalid @errorId}}
      class="d-form-control-input"
      ...attributes
      {{on "input" this.handleInput}}
    />

    <FormMeta
      @description={{@description}}
      @disabled={{@disabled}}
      @value={{@value}}
      @maxLength={{@maxLength}}
      @errorId={{@errorId}}
      @errors={{@errors}}
    />
  </template>
}
