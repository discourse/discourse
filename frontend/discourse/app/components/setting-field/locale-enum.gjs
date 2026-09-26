import { service } from "discourse/lib/service";
import EnumControl from "discourse/components/setting-field/enum";
import LanguageNameLookupService from "discourse/services/language-name-lookup";

export default class SettingFieldLocaleEnum extends EnumControl {
  @service(() => LanguageNameLookupService) languageNameLookup;

  get rawChoices() {
    return super.rawChoices.map(({ value }) => ({
      value,
      name: this.languageNameLookup.getLanguageName(value),
    }));
  }
}
