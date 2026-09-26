import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "discourse/lib/service";
import ListSetting from "discourse/select-kit/components/list-setting";
import SiteSettingsService from "discourse/services/site-settings";

export default class LocaleList extends Component {
  @service(() => SiteSettingsService) siteSettings;

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
      @choices={{this.choices}}
      @nameProperty="name"
      @onChange={{this.onChangeListSetting}}
      @options={{hash allowAny=@allowAny}}
      @settingName={{@setting.setting}}
      @value={{this.settingValue}}
      @valueProperty="value"
    />
  </template>
}
