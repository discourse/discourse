import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import FieldInputDescription from "discourse/admin/components/schema-setting/field-input-description";
import ComboBox from "discourse/select-kit/components/combo-box";
import { not } from "discourse/truth-helpers";

export default class SchemaSettingTypeEnum extends Component {
  get content() {
    return this.args.spec.choices.map((choice) => ({
      name: choice,
      id: choice,
    }));
  }

  <template>
    <ComboBox
      @content={{this.content}}
      @onChange={{@onChange}}
      @options={{hash clearable=(not @spec.required)}}
      @value={{@value}}
    />
    <FieldInputDescription @description={{@description}} />
  </template>
}
