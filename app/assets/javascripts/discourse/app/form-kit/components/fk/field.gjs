import Component from "@glimmer/component";
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
import FKFieldData from "discourse/form-kit/components/fk/field-data";
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
  get wrapper() {
    if (this.args.size) {
      return RowColWrapper;
    } else {
      return EmptyWrapper;
    }
  }

  <template>
    <FKFieldData
      @name={{@name}}
      @data={{@data}}
      @triggerRevalidationFor={{@triggerRevalidationFor}}
      @title={{@title}}
      @description={{@description}}
      @helpText={{@helpText}}
      @showTitle={{@showTitle}}
      @collectionIndex={{@collectionIndex}}
      @set={{@set}}
      @addError={{@addError}}
      @validate={{@validate}}
      @validation={{@validation}}
      @onSet={{@onSet}}
      @registerField={{@registerField}}
      @format={{@format}}
      @disabled={{@disabled}}
      @parentName={{@parentName}}
      as |field|
    >
      <this.wrapper @size={{@size}}>
        {{yield
          (hash
            Custom=(component
              FKControlWrapper
              unregisterField=@unregisterField
              errors=@errors
              component=FKControlCustom
              field=field
            )
            Code=(component
              FKControlWrapper
              unregisterField=@unregisterField
              errors=@errors
              component=FKControlCode
              field=field
            )
            Question=(component
              FKControlWrapper
              unregisterField=@unregisterField
              errors=@errors
              component=FKControlQuestion
              field=field
            )
            Textarea=(component
              FKControlWrapper
              unregisterField=@unregisterField
              errors=@errors
              component=FKControlTextarea
              field=field
            )
            Checkbox=(component
              FKControlWrapper
              unregisterField=@unregisterField
              errors=@errors
              component=FKControlCheckbox
              field=field
            )
            Image=(component
              FKControlWrapper
              unregisterField=@unregisterField
              errors=@errors
              component=FKControlImage
              field=field
            )
            Password=(component
              FKControlWrapper
              unregisterField=@unregisterField
              errors=@errors
              component=FKControlPassword
              field=field
            )
            Composer=(component
              FKControlWrapper
              unregisterField=@unregisterField
              errors=@errors
              component=FKControlComposer
              field=field
            )
            Icon=(component
              FKControlWrapper
              unregisterField=@unregisterField
              errors=@errors
              component=FKControlIcon
              field=field
            )
            Toggle=(component
              FKControlWrapper
              unregisterField=@unregisterField
              errors=@errors
              component=FKControlToggle
              field=field
            )
            Menu=(component
              FKControlWrapper
              unregisterField=@unregisterField
              errors=@errors
              component=FKControlMenu
              field=field
            )
            Select=(component
              FKControlWrapper
              unregisterField=@unregisterField
              errors=@errors
              component=FKControlSelect
              field=field
            )
            Input=(component
              FKControlWrapper
              unregisterField=@unregisterField
              errors=@errors
              component=FKControlInput
              field=field
            )
            RadioGroup=(component
              FKControlWrapper
              unregisterField=@unregisterField
              errors=@errors
              component=FKControlRadioGroup
              field=field
            )
            errorId=field.errorId
            id=field.id
            name=field.name
            set=field.set
            value=field.value
          )
        }}
      </this.wrapper>
    </FKFieldData>
  </template>
}
