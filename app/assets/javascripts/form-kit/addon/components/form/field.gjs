import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { assert } from "@ember/debug";
import { fn, hash } from "@ember/helper";
import { action, get } from "@ember/object";
import { next } from "@ember/runloop";
import concatClass from "discourse/helpers/concat-class";
import uniqueId from "discourse/helpers/unique-id";
import FormFieldsCheckbox from "./fields/checkbox";
import FormFieldsInput from "./fields/input";

export default class FormField extends Component {
  @tracked field;

  constructor() {
    super(...arguments);

    assert(
      "Nested property paths in @name are not supported.",
      typeof this.args.name !== "string" || !this.args.name.includes(".")
    );

    next(() => {
      this.field = this.args.registerField(this.args.name, {
        validate: this.args.validate,
        validation: this.args.validation,
        type: this.args.type,
        disabled: this.args.disabled,
      });
    });
  }

  willDestroy() {
    this.args.unregisterField(this.args.name);

    super.willDestroy();
  }

  get value() {
    return get(this.args.data, this.args.name);
  }

  get errors() {
    return this.args.errors?.[this.args.name];
  }

  get hasErrors() {
    return this.errors !== undefined;
  }

  get showMeta() {
    return this.args.description || this.hasErrors;
  }

  get componentForField() {
    if (this.args.type === "checkbox") {
      return FormFieldsCheckbox;
    }

    return FormFieldsInput;
  }

  @action
  setValue(value) {
    this.args.set(this.args.name, value);
  }

  <template>
    {{log "required" this.field.required}}
    {{#let (uniqueId) (uniqueId) as |fieldId errorId|}}
      <this.componentForField
        @name={{@name}}
        @label={{@label}}
        @disabled={{@disabled}}
        @help={{@help}}
        @description={{@description}}
        @fieldId={{fieldId}}
        @errorId={{errorId}}
        @value={{this.value}}
        @setValue={{this.setValue}}
        @invalid={{this.hasErrors}}
        @errors={{this.errors}}
        @required={{this.field.required}}
        ...attributes
      />
    {{/let}}
  </template>
}
