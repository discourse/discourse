import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ListSetting from "select-kit/components/list-setting";

export default class LocaleList extends Component {
  @service siteSettings;

  tokenSeparator = "|";

  get choices() {
    const allLocales = this.siteSettings.available_locales;
    return this.args.setting.validValues.map(({ value, name }) => ({
      name: allLocales.find((locale) => locale.value === value)?.name || name,
      value,
    }));
  }

  get settingValue() {
    return this.args.value
      .toString()
      .split(this.tokenSeparator)
      .filter(Boolean);
  }

  @action
  onChangeListSetting(value) {
    this.args.changeValueCallback(value.join(this.tokenSeparator));
  }

  <template>
    <ListSetting
      @value={{this.settingValue}}
      @settingName={{@setting.setting}}
      @choices={{this.choices}}
      @nameProperty="name"
      @valueProperty="value"
      @onChange={{this.onChangeListSetting}}
      @options={{hash allowAny=@allowAny}}
    />
  </template>
}
