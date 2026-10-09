import { service } from "@ember/service";
import EnumControl from "discourse/components/setting-field/enum";

export default class SettingFieldLocaleEnum extends EnumControl {
  @service languageNameLookup;

  get rawChoices() {
    return super.rawChoices.map(({ value }) => ({
      value,
      name: this.languageNameLookup.getLanguageName(value),
    }));
  }
}
