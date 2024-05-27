import Component from "@glimmer/component";
import { assert } from "@ember/debug";
import { fn, hash } from "@ember/helper";
import { action, get } from "@ember/object";
import Label from "form-kit/components/label";
import concatClass from "discourse/helpers/concat-class";
import uniqueId from "discourse/helpers/unique-id";
import FormErrors from "./errors";
import FormInput from "./input";

export default class FormField extends Component {
  constructor(owner, args) {
    super(owner, args);

    assert(
      "Nested property paths in @name are not supported.",
      typeof this.args.name !== "string" || !this.args.name.includes(".")
    );

    this.args.registerField(this.args.name, {
      validate: this.args.validate,
      validation: this.args.validation,
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
    this.args.set(this.args.name, value);
  }

  <template>
    <div class={{concatClass "form-group"}}>
      {{#if @label}}
        <Label @label={{@label}} @for={{@name}} />
      {{/if}}

      {{#if @help}}
        <p class="d-form-field__info">{{@help}}</p>
      {{/if}}

      <div>
        {{#let
          (uniqueId) (uniqueId) (fn @set @name) (fn @triggerValidationFor @name)
          as |fieldId errorId setValue triggerValidation|
        }}
          {{yield
            (hash
              Input=(component
                FormInput
                name=@name
                fieldId=fieldId
                errorId=errorId
                value=this.value
                setValue=this.setValue
                invalid=this.hasErrors
              )
              triggerValidation=triggerValidation
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
