import { computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import { i18n } from "discourse-i18n";
import ComboBoxComponent from "select-kit/components/combo-box";
import {
  pluginApiIdentifiers,
  selectKitOptions,
} from "select-kit/components/select-kit";

@selectKitOptions({
  filterable: true,
  allowAny: false,
  translatedNone: i18n(
    "discourse_subscriptions.subscribe.cardholder_address.province"
  ),
})
@pluginApiIdentifiers("subscribe-ca-province-select")
@classNames("subscribe-address-state-select")
export default class SubscribeCaProvinceSelect extends ComboBoxComponent {
  nameProperty = "name";
  valueProperty = "value";

  @computed
  get content() {
    return [
      ["AB", "Alberta"],
      ["BC", "British Columbia"],
      ["MB", "Manitoba"],
      ["NB", "New Brunswick"],
      ["NL", "Newfoundland and Labrador"],
      ["NT", "Northwest Territories"],
      ["NS", "Nova Scotia"],
      ["NU", "Nunavut"],
      ["ON", "Ontario"],
      ["PE", "Prince Edward Island"],
      ["QC", "Quebec"],
      ["SK", "Saskatchewan"],
      ["YT", "Yukon"],
    ].map((arr) => {
      return { value: arr[0], name: arr[1] };
    });
  }
}
