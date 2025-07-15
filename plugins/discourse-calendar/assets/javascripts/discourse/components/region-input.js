import { computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import { i18n } from "discourse-i18n";
import ComboBoxComponent from "select-kit/components/combo-box";
import {
  pluginApiIdentifiers,
  selectKitOptions,
} from "select-kit/components/select-kit";
import { HOLIDAY_REGIONS } from "../lib/regions";

@selectKitOptions({
  filterable: true,
  allowAny: false,
})
@pluginApiIdentifiers("timezone-input")
@classNames("timezone-input", "region-input")
export default class RegionInput extends ComboBoxComponent {
  allowNoneRegion = false;

  @computed
  get content() {
    const localeNames = {};
    let regions = [];

    JSON.parse(this.siteSettings.available_locales).forEach((locale) => {
      localeNames[locale.value] = locale.name;
    });

    if (this.allowNoneRegion === true) {
      regions.push({
        name: i18n("discourse_calendar.region.none"),
        id: null,
      });
    }

    regions = regions.concat(
      HOLIDAY_REGIONS.map((region) => ({
        name: i18n(`discourse_calendar.region.names.${region}`),
        id: region,
      })).sort((a, b) => a.name.localeCompare(b.name))
    );
    return regions;
  }
}
