import { computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import { makeArray } from "discourse/lib/helpers";
import MultiSelectComponent from "select-kit/components/multi-select";

@classNames("house-ads-chooser")
export default class HouseAdsChooser extends MultiSelectComponent {
  filterable = true;
  filterPlaceholder = "admin.adplugin.house_ads.filter_placeholder";
  tokenSeparator = "|";
  allowCreate = false;
  allowAny = false;
  settingValue = "";
  valueAttribute = null;
  nameProperty = null;

  @computed("settingValue")
  get value() {
    return this.settingValue
      .toString()
      .split(this.tokenSeparator)
      .filter(Boolean);
  }

  computeValues() {
    return this.settingValue.split(this.tokenSeparator).filter(Boolean);
  }

  @computed("choices")
  get content() {
    return makeArray(this.choices);
  }
}
