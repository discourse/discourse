import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ComboBox from "discourse/select-kit/components/combo-box";

export default class LocaleEnum extends Component {
  @service languageNameLookup;

  get content() {
    return this.args.setting.validValues.map(({ value }) => ({
      name: this.languageNameLookup.getLanguageName(value),
      value,
    }));
  }

  @action
  onChangeLocale(value) {
    this.args.changeValueCallback(value);
  }

  <template>
    <ComboBox
      @content={{this.content}}
      @nameProperty={{@setting.computedNameProperty}}
      @onChange={{this.onChangeLocale}}
      @options={{hash castInteger=true allowAny=@setting.allowsNone}}
      @value={{@value}}
      @valueProperty={{@setting.computedValueProperty}}
    />

    {{@preview}}
  </template>
}
