import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { assert } from "@ember/debug";
import { fn, hash } from "@ember/helper";
import { action, get } from "@ember/object";
import Label from "form-kit/components/label";
import concatClass from "discourse/helpers/concat-class";
import uniqueId from "discourse/helpers/unique-id";
import FormControlCheckbox from "./control/checkbox";
import FormControlInput from "./control/input";
import FormControlToggle from "./control/toggle";
import FormErrors from "./errors";

export default class FormField extends Component {
  @tracked field;

  @action
  registerFieldWithType(type) {
    assert(
      "Nested property paths in @name are not supported.",
      typeof this.args.name !== "string" || !this.args.name.includes(".")
    );

    this.field = this.args.registerField(this.args.name, {
      validate: this.args.validate,
      validation: this.args.validation,
      type,
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

  @action
  setValue(value) {
    console.log("setting value", this.args.name, value);
    this.args.set(this.args.name, value);
  }

  <template>
    -----------------

    {{log this.field}}
    -------------------
    <div class="form-field">
      {{#if @label}}
        <Label @label={{@label}} @for={{@name}} />
      {{/if}}

      {{#if @help}}
        <p class="d-form-field__info">{{@help}}</p>
      {{/if}}

      <div class="d-form-field__value">
        {{#let
          (uniqueId) (uniqueId) (fn @set @name) (fn @triggerValidationFor @name)
          as |fieldId errorId setValue triggerValidation|
        }}
          {{yield
            (hash
              Input=(component
                FormControlInput
                name=@name
                fieldId=fieldId
                errorId=errorId
                value=this.value
                setValue=this.setValue
                invalid=this.hasErrors
                registerFieldWithType=this.registerFieldWithType
              )
              Checkbox=(component
                FormControlCheckbox
                name=@name
                fieldId=fieldId
                errorId=errorId
                value=this.value
                setValue=this.setValue
                invalid=this.hasErrors
                registerFieldWithType=(this.registerFieldWithType "boolean")
              )
              Toggle=(component
                FormControlToggle
                name=@name
                fieldId=fieldId
                errorId=errorId
                value=this.value
                setValue=this.setValue
                invalid=this.hasErrors
                registerFieldWithType=(this.registerFieldWithType "boolean")
              )
              triggerValidation=triggerValidation
              setValue=setValue
              id=fieldId
              errorId=errorId
            )
          }}

          {{#if this.showMeta}}
            <div class="d-form-field__meta">
              {{#if this.hasErrors}}
                <FormErrors @id={{errorId}} @errors={{this.errors}} />
              {{else if @description}}
                <p class="d-form-field__meta-text">{{@description}}</p>
              {{/if}}
            </div>
          {{/if}}
        {{/let}}
      </div>
    </div>
  </template>
}
