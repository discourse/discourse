import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import curryComponent from "ember-curry-component";
import FKControlCalendar from "discourse/form-kit/components/fk/control/calendar";
import FKControlCheckbox from "discourse/form-kit/components/fk/control/checkbox";
import FKControlCode from "discourse/form-kit/components/fk/control/code";
import FKControlComposer from "discourse/form-kit/components/fk/control/composer";
import FKControlCustom from "discourse/form-kit/components/fk/control/custom";
import FKControlEmoji from "discourse/form-kit/components/fk/control/emoji";
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

  @action
  componentFor(component, field) {
    const instance = this;
    const baseArguments = {
      get errors() {
        return instance.args.errors;
      },
      unregisterField: instance.args.unregisterField,
      registerField: instance.args.registerField,
      component,
      field,
    };

    if (!component.controlType) {
      throw new Error(
        `Static property \`controlType\` is required on component:\n\n ${component}`
      );
    }

    return curryComponent(FKControlWrapper, baseArguments, getOwner(this));
  }

  <template>
    <FKFieldData
      @name={{@name}}
      @data={{@data}}
      @triggerRevalidationFor={{@triggerRevalidationFor}}
      @title={{@title}}
      @tooltip={{@tooltip}}
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
      @titleFormat={{@titleFormat}}
      @descriptionFormat={{@descriptionFormat}}
      @disabled={{@disabled}}
      @parentName={{@parentName}}
      @placeholderUrl={{@placeholderUrl}}
      as |field|
    >
      <this.wrapper @size={{@size}}>
        {{yield
          (hash
            Custom=(this.componentFor FKControlCustom field)
            Code=(this.componentFor FKControlCode field)
            Question=(this.componentFor FKControlQuestion field)
            Textarea=(this.componentFor FKControlTextarea field)
            Checkbox=(this.componentFor FKControlCheckbox field)
            Image=(this.componentFor FKControlImage field)
            Password=(this.componentFor FKControlPassword field)
            Composer=(this.componentFor FKControlComposer field)
            Icon=(this.componentFor FKControlIcon field)
            Emoji=(this.componentFor FKControlEmoji field)
            Toggle=(this.componentFor FKControlToggle field)
            Menu=(this.componentFor FKControlMenu field)
            Select=(this.componentFor FKControlSelect field)
            Input=(this.componentFor FKControlInput field)
            RadioGroup=(this.componentFor FKControlRadioGroup field)
            Calendar=(this.componentFor FKControlCalendar field)
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
