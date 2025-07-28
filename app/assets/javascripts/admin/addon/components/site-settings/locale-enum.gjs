import Component from "@ember/component";
import { fn, hash } from "@ember/helper";
import { service } from "@ember/service";
import ComboBox from "select-kit/components/combo-box";

export default class LocaleEnum extends Component {
  @service languageNameLookup;

  get content() {
    return this.setting.validValues.map(({ value }) => ({
      name: this.languageNameLookup.getLanguageName(value),
      value,
    }));
  }

  <template>
    <ComboBox
      @content={{this.content}}
      @value={{this.value}}
      @onChange={{fn (mut this.value)}}
      @valueProperty={{this.setting.computedValueProperty}}
      @nameProperty={{this.setting.computedNameProperty}}
      @options={{hash castInteger=true allowAny=this.setting.allowsNone}}
    />

    {{this.preview}}
  </template>
}
