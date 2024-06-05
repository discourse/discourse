import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { assert } from "@ember/debug";
import { fn, hash } from "@ember/helper";
import { action, get } from "@ember/object";
import { next } from "@ember/runloop";
import FkControlIconPicker from "form-kit/components/control/icon-picker";
import FkControlImage from "form-kit/components/control/image";
import FkControlInput from "form-kit/components/control/input";
import FkControlMenu from "form-kit/components/control/menu";
import FkControlRadioGroup from "form-kit/components/control/radio-group";
import FkControlSelect from "form-kit/components/control/select";
import concatClass from "discourse/helpers/concat-class";
import uniqueId from "discourse/helpers/unique-id";

export default class FormField extends Component {
  constructor() {
    super(...arguments);

    assert(
      "Nested property paths in @name are not supported.",
      typeof this.args.name !== "string" || !this.args.name.includes(".")
    );

    this.args.registerField(this.args.name, {
      validate: this.args.validate,
      disabled: this.args.disabled,
      validation: this.args.validation,
    });
  }

  willDestroy() {
    this.args.unregisterField(this.args.name);

    super.willDestroy();
  }

  get inputGroup() {
    return this.args.inputGroup ?? false;
  }

  get value() {
    return get(this.args.data, this.args.name);
  }

  get errors() {
    return { [this.args.name]: this.args.errors?.[this.args.name] };
  }

  get hasErrors() {
    return this.errors !== undefined;
  }

  get showMeta() {
    return this.args.showMeta ?? true;
  }

  @action
  setValue(value) {
    this.args.set(this.args.name, value);
  }

  <template>
    {{#let (uniqueId) (uniqueId) as |fieldId errorId|}}
      {{yield
        (hash
          Image=(component
            FkControlImage
            name=@name
            fieldId=fieldId
            errorId=errorId
            setValue=this.setValue
            value=this.value
            errors=this.errors
            triggerValidationFor=@triggerValidationFor
          )
          IconPicker=(component
            FkControlIconPicker
            name=@name
            fieldId=fieldId
            errorId=errorId
            setValue=this.setValue
            value=this.value
            errors=this.errors
            triggerValidationFor=@triggerValidationFor
          )
          Menu=(component
            FkControlMenu
            name=@name
            fieldId=fieldId
            errorId=errorId
            setValue=this.setValue
            value=this.value
            errors=this.errors
            triggerValidationFor=@triggerValidationFor
          )
          Select=(component
            FkControlSelect
            name=@name
            fieldId=fieldId
            errorId=errorId
            setValue=this.setValue
            value=this.value
            errors=this.errors
            triggerValidationFor=@triggerValidationFor
          )
          Input=(component
            FkControlInput
            name=@name
            fieldId=fieldId
            errorId=errorId
            setValue=this.setValue
            value=this.value
            errors=this.errors
            triggerValidationFor=@triggerValidationFor
          )
          RadioGroup=(component
            FkControlRadioGroup
            name=@name
            fieldId=fieldId
            errorId=errorId
            setValue=this.setValue
            value=this.value
            errors=this.errors
            triggerValidationFor=@triggerValidationFor
          )
          id=fieldId
          setValue=this.setValue
        )
      }}
    {{/let}}
  </template>
}
