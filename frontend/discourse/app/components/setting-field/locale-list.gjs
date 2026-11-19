import { service } from "@ember/service";
import CompactListControl from "discourse/components/setting-field/compact-list";

export default class SettingFieldLocaleList extends CompactListControl {
  @service languageNameLookup;

  get choices() {
    return super.choices.map(({ value }) => ({
      value,
      name: this.languageNameLookup.getLanguageName(value),
    }));
  }
}
