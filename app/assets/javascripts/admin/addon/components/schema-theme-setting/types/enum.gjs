import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import ComboBox from "select-kit/components/combo-box";

export default class SchemaThemeSettingTypeEnum extends Component {
  @tracked value = this.args.value;

  get content() {
    return this.args.spec.choices.map((choice) => {
      return {
        name: choice,
        id: choice,
      };
    });
  }

  @action
  onInput(newVal) {
    this.value = newVal;
    this.args.onChange(newVal);
  }

  <template>
    <ComboBox
      @content={{this.content}}
      @value={{this.value}}
      @onChange={{this.onInput}}
    />
  </template>
}
