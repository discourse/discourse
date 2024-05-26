import Component from "@glimmer/component";
import { assert } from "@ember/debug";
import { fn, hash } from "@ember/helper";
import { action, get } from "@ember/object";
import Label from "form-kit/components/label";
import concatClass from "discourse/helpers/concat-class";
import uniqueId from "discourse/helpers/unique-id";
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
    // when @mutableData is set, data is something we don't control, i.e. might require old-school get() to be on the safe side
    // we do not want to support nested property paths for now though, see the constructor assertion!
    return get(this.args.data, this.args.name);
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
        {{/let}}

        {{#if @description}}
          <div class="d-form-field__meta">
            <p class="d-form-field__meta-text">{{@description}}</p>
          </div>
        {{/if}}
      </div>
    </div>
  </template>
}
