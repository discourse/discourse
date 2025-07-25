import Component from "@ember/component";
import { hash } from "@ember/helper";
import { action, computed } from "@ember/object";
import { service } from "@ember/service";
import ListSetting from "select-kit/components/list-setting";

export default class LocaleList extends Component {
  tokenSeparator = "|";

  @service siteSettings;

  @computed("value")
  get settingValue() {
    return this.value.toString().split(this.tokenSeparator).filter(Boolean);
  }

  @action
  onChangeListSetting(value) {
    this.set("value", value.join(this.tokenSeparator));
  }

  @action
  modifyContent(content) {
    const allLocales = this.siteSettings.available_locales;
    return content.map(({ value, name }) => ({
      name: allLocales.find((locale) => locale.value === value)?.name || name,
      value,
    }));
  }

  <template>
    <ListSetting
      @value={{this.settingValue}}
      @settingName={{this.setting.setting}}
      @choices={{this.setting.validValues}}
      @modifyContent={{this.modifyContent}}
      @nameProperty="name"
      @valueProperty="value"
      @onChange={{this.onChangeListSetting}}
      @options={{hash allowAny=this.allowAny}}
    />
  </template>
}
