import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { assert } from "@ember/debug";
import { hash } from "@ember/helper";
import { get } from "@ember/object";
import FKControlCheckbox from "discourse/form-kit/components/control/checkbox";
import FKControlCode from "discourse/form-kit/components/control/code";
import FKControlComposer from "discourse/form-kit/components/control/composer";
import FKControlIcon from "discourse/form-kit/components/control/icon";
import FKControlImage from "discourse/form-kit/components/control/image";
import FKControlInput from "discourse/form-kit/components/control/input";
import FKControlMenu from "discourse/form-kit/components/control/menu";
import FKControlQuestion from "discourse/form-kit/components/control/question";
import FKControlRadioGroup from "discourse/form-kit/components/control/radio-group";
import FKControlSelect from "discourse/form-kit/components/control/select";
import FKControlText from "discourse/form-kit/components/control/text";
import FKControlToggle from "discourse/form-kit/components/control/toggle";
import FKControlWrapper from "discourse/form-kit/components/control-wrapper";
import FKRow from "discourse/form-kit/components/row";

export default class FormField extends Component {
  @tracked field;

  constructor() {
    super(...arguments);

    assert(
      "Nested property paths in @name are not supported.",
      typeof this.args.name !== "string" || !this.args.name.includes(".")
    );

    this.field = this.args.registerField(this.args.name, {
      set: this.args.set,
      validate: this.args.validate,
      disabled: this.args.disabled,
      validation: this.args.validation,
      onSet: this.args.onSet,
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
      return <template>
        {{! template-lint-disable no-yield-only }}
        {{yield}}
      </template>;
    }
  }

  <template>
    <this.wrapper @size={{@size}}>
      {{yield
        (hash
          Code=(component
            FKControlWrapper
            component=FKControlCode
            value=this.value
            errors=this.errors
            hasErrors=this.hasErrors
            triggerValidationFor=@triggerValidationFor
            field=this.field
          )
          Question=(component
            FKControlWrapper
            component=FKControlQuestion
            value=this.value
            errors=this.errors
            hasErrors=this.hasErrors
            triggerValidationFor=@triggerValidationFor
            field=this.field
          )
          Text=(component
            FKControlWrapper
            component=FKControlText
            value=this.value
            errors=this.errors
            hasErrors=this.hasErrors
            triggerValidationFor=@triggerValidationFor
            field=this.field
          )
          Checkbox=(component
            FKControlWrapper
            component=FKControlCheckbox
            value=this.value
            errors=this.errors
            hasErrors=this.hasErrors
            triggerValidationFor=@triggerValidationFor
            field=this.field
          )
          Image=(component
            FKControlWrapper
            component=FKControlImage
            value=this.value
            errors=this.errors
            hasErrors=this.hasErrors
            triggerValidationFor=@triggerValidationFor
            field=this.field
          )
          Composer=(component
            FKControlWrapper
            component=FKControlComposer
            value=this.value
            errors=this.errors
            hasErrors=this.hasErrors
            triggerValidationFor=@triggerValidationFor
            field=this.field
          )
          Icon=(component
            FKControlWrapper
            component=FKControlIcon
            value=this.value
            errors=this.errors
            hasErrors=this.hasErrors
            triggerValidationFor=@triggerValidationFor
            field=this.field
          )
          Toggle=(component
            FKControlWrapper
            component=FKControlToggle
            value=this.value
            errors=this.errors
            hasErrors=this.hasErrors
            triggerValidationFor=@triggerValidationFor
            field=this.field
          )
          Menu=(component
            FKControlWrapper
            component=FKControlMenu
            value=this.value
            errors=this.errors
            hasErrors=this.hasErrors
            triggerValidationFor=@triggerValidationFor
            field=this.field
          )
          Select=(component
            FKControlWrapper
            component=FKControlSelect
            value=this.value
            errors=this.errors
            hasErrors=this.hasErrors
            triggerValidationFor=@triggerValidationFor
            field=this.field
          )
          Input=(component
            FKControlWrapper
            component=FKControlInput
            value=this.value
            errors=this.errors
            hasErrors=this.hasErrors
            triggerValidationFor=@triggerValidationFor
            field=this.field
          )
          RadioGroup=(component
            FKControlWrapper
            component=FKControlRadioGroup
            value=this.value
            errors=this.errors
            hasErrors=this.hasErrors
            triggerValidationFor=@triggerValidationFor
            field=this.field
          )
          errorId=this.field.errorId
          id=this.field.id
          name=this.field.name
          set=this.field.set
          value=this.value
        )
      }}
    </this.wrapper>
  </template>
}
