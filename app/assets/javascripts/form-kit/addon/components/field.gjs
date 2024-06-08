import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { assert } from "@ember/debug";
import { hash } from "@ember/helper";
import { action, get } from "@ember/object";
import FkControlCheckbox from "form-kit/components/control/checkbox";
import FkControlIconPicker from "form-kit/components/control/icon-picker";
import FkControlImage from "form-kit/components/control/image";
import FkControlInput from "form-kit/components/control/input";
import FkControlMenu from "form-kit/components/control/menu";
import FkControlRadioGroup from "form-kit/components/control/radio-group";
import FkControlSelect from "form-kit/components/control/select";
import FkControlText from "form-kit/components/control/text";
import FkControlWrapper from "form-kit/components/control-wrapper";
import Row from "form-kit/components/row";
import uniqueId from "discourse/helpers/unique-id";

export default class FormField extends Component {
  @tracked field;

  constructor() {
    super(...arguments);

    assert(
      "Nested property paths in @name are not supported.",
      typeof this.args.name !== "string" || !this.args.name.includes(".")
    );

    this.field = this.args.registerField(this.args.name, {
      validate: this.args.validate,
      disabled: this.args.disabled,
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

  get wrapper() {
    if (this.args.size) {
      return <template>
        <Row as |row|>
          <row.Col @size={{@size}}>
            {{yield}}
          </row.Col>
        </Row>
      </template>;
    } else {
      return <template>{{yield}}</template>;
    }
  }

  <template>
    <this.wrapper @size={{@size}}>
      {{#let (uniqueId) (uniqueId) as |fieldId errorId|}}
        {{yield
          (hash
            Text=(component
              FkControlWrapper
              component=FkControlText
              name=@name
              fieldId=fieldId
              errorId=errorId
              setValue=this.setValue
              value=this.value
              errors=this.errors
              triggerValidationFor=@triggerValidationFor
              field=this.field
            )
            Checkbox=(component
              FkControlCheckbox
              name=@name
              fieldId=fieldId
              errorId=errorId
              setValue=this.setValue
              value=this.value
              errors=this.errors
              triggerValidationFor=@triggerValidationFor
              field=this.field
            )
            Image=(component
              FkControlWrapper
              component=FkControlImage
              name=@name
              fieldId=fieldId
              errorId=errorId
              setValue=this.setValue
              value=this.value
              errors=this.errors
              triggerValidationFor=@triggerValidationFor
            )
            IconPicker=(component
              FkControlWrapper
              component=FkControlIconPicker
              name=@name
              fieldId=fieldId
              errorId=errorId
              setValue=this.setValue
              value=this.value
              errors=this.errors
              triggerValidationFor=@triggerValidationFor
              field=this.field
            )
            Menu=(component
              FkControlWrapper
              component=FkControlMenu
              name=@name
              fieldId=fieldId
              errorId=errorId
              setValue=this.setValue
              value=this.value
              errors=this.errors
              triggerValidationFor=@triggerValidationFor
              field=this.field
            )
            Select=(component
              FkControlWrapper
              component=FkControlSelect
              name=@name
              fieldId=fieldId
              errorId=errorId
              setValue=this.setValue
              value=this.value
              errors=this.errors
              triggerValidationFor=@triggerValidationFor
              field=this.field
            )
            Input=(component
              FkControlWrapper
              component=FkControlInput
              name=@name
              fieldId=fieldId
              errorId=errorId
              setValue=this.setValue
              value=this.value
              errors=this.errors
              triggerValidationFor=@triggerValidationFor
              field=this.field
            )
            RadioGroup=(component
              FkControlWrapper
              component=FkControlRadioGroup
              name=@name
              fieldId=fieldId
              errorId=errorId
              setValue=this.setValue
              value=this.value
              errors=this.errors
              triggerValidationFor=@triggerValidationFor
              field=this.field
            )
            id=fieldId
            setValue=this.setValue
          )
        }}
      {{/let}}
    </this.wrapper>
  </template>
}
