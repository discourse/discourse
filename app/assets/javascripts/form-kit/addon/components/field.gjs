import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { assert } from "@ember/debug";
import { hash } from "@ember/helper";
import { action, get } from "@ember/object";
import FKControlCheckbox from "form-kit/components/control/checkbox";
import FKControlCode from "form-kit/components/control/code";
import FKControlIcon from "form-kit/components/control/icon";
import FKControlImage from "form-kit/components/control/image";
import FKControlInput from "form-kit/components/control/input";
import FKControlMenu from "form-kit/components/control/menu";
import FKControlQuestion from "form-kit/components/control/question";
import FKControlRadioGroup from "form-kit/components/control/radio-group";
import FKControlSelect from "form-kit/components/control/select";
import FKControlText from "form-kit/components/control/text";
import FKControlWrapper from "form-kit/components/control-wrapper";
import FKRow from "form-kit/components/row";
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
    return Object.values(this.errors).flat().compact().length;
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
        <FKRow as |row|>
          <row.Col @size={{@size}}>
            {{yield}}
          </row.Col>
        </FKRow>
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
            Code=(component
              FKControlWrapper
              component=FKControlCode
              name=@name
              disabled=@disabled
              fieldId=fieldId
              errorId=errorId
              setValue=this.setValue
              value=this.value
              errors=this.errors
              hasErrors=this.hasErrors
              triggerValidationFor=@triggerValidationFor
              field=this.field
              onSet=@onSet
              onUnset=@onUnset
              set=@set
            )
            Question=(component
              FKControlWrapper
              component=FKControlQuestion
              name=@name
              disabled=@disabled
              fieldId=fieldId
              errorId=errorId
              setValue=this.setValue
              value=this.value
              errors=this.errors
              hasErrors=this.hasErrors
              triggerValidationFor=@triggerValidationFor
              field=this.field
              onSet=@onSet
              onUnset=@onUnset
              set=@set
            )
            Text=(component
              FKControlWrapper
              component=FKControlText
              name=@name
              disabled=@disabled
              fieldId=fieldId
              errorId=errorId
              setValue=this.setValue
              value=this.value
              errors=this.errors
              hasErrors=this.hasErrors
              triggerValidationFor=@triggerValidationFor
              field=this.field
              onSet=@onSet
              onUnset=@onUnset
              set=@set
            )
            Checkbox=(component
              FKControlCheckbox
              name=@name
              disabled=@disabled
              fieldId=fieldId
              errorId=errorId
              setValue=this.setValue
              value=this.value
              errors=this.errors
              hasErrors=this.hasErrors
              triggerValidationFor=@triggerValidationFor
              field=this.field
              onSet=@onSet
              onUnset=@onUnset
              set=@set
            )
            Image=(component
              FKControlWrapper
              component=FKControlImage
              name=@name
              disabled=@disabled
              fieldId=fieldId
              errorId=errorId
              setValue=this.setValue
              value=this.value
              errors=this.errors
              hasErrors=this.hasErrors
              triggerValidationFor=@triggerValidationFor
              field=this.field
              onSet=@onSet
              onUnset=@onUnset
              set=@set
            )
            Icon=(component
              FKControlWrapper
              component=FKControlIcon
              name=@name
              disabled=@disabled
              fieldId=fieldId
              errorId=errorId
              setValue=this.setValue
              value=this.value
              errors=this.errors
              hasErrors=this.hasErrors
              triggerValidationFor=@triggerValidationFor
              field=this.field
              onSet=@onSet
              onUnset=@onUnset
              set=@set
            )
            Menu=(component
              FKControlWrapper
              component=FKControlMenu
              name=@name
              disabled=@disabled
              fieldId=fieldId
              errorId=errorId
              setValue=this.setValue
              value=this.value
              errors=this.errors
              hasErrors=this.hasErrors
              triggerValidationFor=@triggerValidationFor
              field=this.field
              onSet=@onSet
              onUnset=@onUnset
              set=@set
            )
            Select=(component
              FKControlWrapper
              component=FKControlSelect
              name=@name
              disabled=@disabled
              fieldId=fieldId
              errorId=errorId
              setValue=this.setValue
              value=this.value
              errors=this.errors
              hasErrors=this.hasErrors
              triggerValidationFor=@triggerValidationFor
              field=this.field
              onSet=@onSet
              onUnset=@onUnset
              set=@set
            )
            Input=(component
              FKControlWrapper
              component=FKControlInput
              name=@name
              disabled=@disabled
              fieldId=fieldId
              errorId=errorId
              setValue=this.setValue
              value=this.value
              errors=this.errors
              hasErrors=this.hasErrors
              triggerValidationFor=@triggerValidationFor
              field=this.field
              onSet=@onSet
              onUnset=@onUnset
              set=@set
            )
            RadioGroup=(component
              FKControlWrapper
              component=FKControlRadioGroup
              name=@name
              disabled=@disabled
              fieldId=fieldId
              errorId=errorId
              setValue=this.setValue
              value=this.value
              errors=this.errors
              hasErrors=this.hasErrors
              triggerValidationFor=@triggerValidationFor
              field=this.field
              onSet=@onSet
              onUnset=@onUnset
              set=@set
            )
            id=fieldId
            setValue=this.setValue
          )
        }}
      {{/let}}
    </this.wrapper>
  </template>
}
