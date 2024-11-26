import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import FKControlCheckbox from "discourse/form-kit/components/fk/control/checkbox";
import FKControlCode from "discourse/form-kit/components/fk/control/code";
import FKControlComposer from "discourse/form-kit/components/fk/control/composer";
import FKControlCustom from "discourse/form-kit/components/fk/control/custom";
import FKControlIcon from "discourse/form-kit/components/fk/control/icon";
import FKControlImage from "discourse/form-kit/components/fk/control/image";
import FKControlInput from "discourse/form-kit/components/fk/control/input";
import FKControlMenu from "discourse/form-kit/components/fk/control/menu";
import FKControlPassword from "discourse/form-kit/components/fk/control/password";
import FKControlQuestion from "discourse/form-kit/components/fk/control/question";
import FKControlRadioGroup from "discourse/form-kit/components/fk/control/radio-group";
import FKControlSelect from "discourse/form-kit/components/fk/control/select";
import FKControlTextarea from "discourse/form-kit/components/fk/control/textarea";
import FKControlToggle from "discourse/form-kit/components/fk/control/toggle";
import FKControlWrapper from "discourse/form-kit/components/fk/control-wrapper";
import FKRow from "discourse/form-kit/components/fk/row";

const RowColWrapper = <template>
  <FKRow as |row|>
    <row.Col @size={{@size}}>
      {{yield}}
    </row.Col>
  </FKRow>
</template>;

const EmptyWrapper = <template>
  {{! template-lint-disable no-yield-only }}
  {{yield}}
</template>;

export default class FKField extends Component {
  @tracked field;
  @tracked name;

  constructor() {
    super(...arguments);

    if (!this.args.title?.length) {
      throw new Error("@title is required on `<form.Field />`.");
    }

    if (typeof this.args.name !== "string") {
      throw new Error(
        "@name is required and must be a string on `<form.Field />`."
      );
    }

    if (this.args.name.includes(".") || this.args.name.includes("-")) {
      throw new Error("@name can't include `.` or `-`.");
    }

    this.name =
      (this.args.collectionName ? `${this.args.collectionName}.` : "") +
      (this.args.collectionIndex !== undefined
        ? `${this.args.collectionIndex}.`
        : "") +
      this.args.name;

    this.field = this.args.registerField(this.name, {
      triggerRevalidationFor: this.args.triggerRevalidationFor,
      title: this.args.title,
      description: this.args.description,
      showTitle: this.args.showTitle,
      collectionIndex: this.args.collectionIndex,
      set: this.args.set,
      addError: this.args.addError,
      validate: this.args.validate,
      validation: this.args.validation,
      onSet: this.args.onSet,
    });
  }

  willDestroy() {
    this.args.unregisterField(this.name);

    super.willDestroy();
  }

  get value() {
    return this.args.data.get(this.name);
  }

  get wrapper() {
    if (this.args.size) {
      return RowColWrapper;
    } else {
      return EmptyWrapper;
    }
  }

  <template>
    <this.wrapper @size={{@size}}>
      {{yield
        (hash
          Custom=(component
            FKControlWrapper
            errors=@errors
            disabled=@disabled
            component=FKControlCustom
            value=this.value
            field=this.field
            format=@format
          )
          Code=(component
            FKControlWrapper
            errors=@errors
            disabled=@disabled
            component=FKControlCode
            value=this.value
            field=this.field
            format=@format
          )
          Question=(component
            FKControlWrapper
            errors=@errors
            disabled=@disabled
            component=FKControlQuestion
            value=this.value
            field=this.field
            format=@format
          )
          Textarea=(component
            FKControlWrapper
            errors=@errors
            disabled=@disabled
            component=FKControlTextarea
            value=this.value
            field=this.field
            format=@format
          )
          Checkbox=(component
            FKControlWrapper
            errors=@errors
            disabled=@disabled
            component=FKControlCheckbox
            value=this.value
            field=this.field
            format=@format
          )
          Image=(component
            FKControlWrapper
            errors=@errors
            disabled=@disabled
            component=FKControlImage
            value=this.value
            field=this.field
            format=@format
          )
          Password=(component
            FKControlWrapper
            errors=@errors
            disabled=@disabled
            component=FKControlPassword
            value=this.value
            field=this.field
            format=@format
          )
          Composer=(component
            FKControlWrapper
            errors=@errors
            disabled=@disabled
            component=FKControlComposer
            value=this.value
            field=this.field
            format=@format
          )
          Icon=(component
            FKControlWrapper
            errors=@errors
            disabled=@disabled
            component=FKControlIcon
            value=this.value
            field=this.field
            format=@format
          )
          Toggle=(component
            FKControlWrapper
            errors=@errors
            disabled=@disabled
            component=FKControlToggle
            value=this.value
            field=this.field
            format=@format
          )
          Menu=(component
            FKControlWrapper
            errors=@errors
            disabled=@disabled
            component=FKControlMenu
            value=this.value
            field=this.field
            format=@format
          )
          Select=(component
            FKControlWrapper
            errors=@errors
            disabled=@disabled
            component=FKControlSelect
            value=this.value
            field=this.field
            format=@format
          )
          Input=(component
            FKControlWrapper
            errors=@errors
            disabled=@disabled
            component=FKControlInput
            value=this.value
            field=this.field
            format=@format
          )
          RadioGroup=(component
            FKControlWrapper
            errors=@errors
            disabled=@disabled
            component=FKControlRadioGroup
            value=this.value
            field=this.field
            format=@format
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
