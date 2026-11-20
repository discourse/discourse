import { action } from "@ember/object";
import { service } from "@ember/service";
import CompactListControl from "discourse/components/setting-field/compact-list";
import { normalizeAllowedUserLocales } from "discourse/lib/content-localization";

export default class SettingFieldLocaleList extends CompactListControl {
  @service languageNameLookup;
  @service siteSettings;

  get choices() {
    return super.choices.map(({ value, name }) => ({
      value,
      name: this.siteSettings.available_locales?.some(
        (locale) => locale.value === value
      )
        ? this.languageNameLookup.getLanguageName(value)
        : name,
    }));
  }

  @action
  onChange(values) {
    if (this.args.definition.key === "allowed_user_locales") {
      values = normalizeAllowedUserLocales(values, this.settingValue);
    }
    super.onChange(values);
  }
}
