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
import FKRow from "discourse/form-kit/components/fk/row";
import FKFieldData from "discourse/form-kit/lib/fk-field-data";

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
      @showTitle={{@showTitle}}
      @collectionIndex={{@collectionIndex}}
      @set={{@set}}
      @addError={{@addError}}
      @validate={{@validate}}
      @validation={{@validation}}
      @onSet={{@onSet}}
      @registerField={{@registerField}}
      @unregisterField={{@unregisterField}}
      @format={{@format}}
      as |field|
    >

      {{log field}}
      <this.wrapper @size={{@size}}>
        {{yield
          (hash
            Custom=(component
              FKControlWrapper
              errors=@errors
              component=FKControlCustom
              field=field
            )
            Code=(component
              FKControlWrapper
              errors=@errors
              component=FKControlCode
              field=field
            )
            Question=(component
              FKControlWrapper
              errors=@errors
              component=FKControlQuestion
              field=field
            )
            Textarea=(component
              FKControlWrapper
              errors=@errors
              component=FKControlTextarea
              field=field
            )
            Checkbox=(component
              FKControlWrapper
              errors=@errors
              component=FKControlCheckbox
              field=field
            )
            Image=(component
              FKControlWrapper
              errors=@errors
              component=FKControlImage
              field=field
            )
            Password=(component
              FKControlWrapper
              errors=@errors
              component=FKControlPassword
              field=field
            )
            Composer=(component
              FKControlWrapper
              errors=@errors
              component=FKControlComposer
              field=field
            )
            Icon=(component
              FKControlWrapper
              errors=@errors
              component=FKControlIcon
              field=field
            )
            Toggle=(component
              FKControlWrapper
              errors=@errors
              component=FKControlToggle
              field=field
            )
            Menu=(component
              FKControlWrapper
              errors=@errors
              component=FKControlMenu
              field=field
            )
            Select=(component
              FKControlWrapper
              errors=@errors
              component=FKControlSelect
              field=field
            )
            Input=(component
              FKControlWrapper
              errors=@errors
              component=FKControlInput
              field=field
            )
            RadioGroup=(component
              FKControlWrapper
              errors=@errors
              component=FKControlRadioGroup
              field=field
            )
            errorId=field.errorId
            id=field.id
            name=field.name
            set=field.set
          )
        }}
      </this.wrapper>
    </FKFieldData>
  </template>
}
