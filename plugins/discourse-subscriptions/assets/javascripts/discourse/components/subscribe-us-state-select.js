import { computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import { i18n } from "discourse-i18n";
import ComboBoxComponent from "select-kit/components/combo-box";
import {
  pluginApiIdentifiers,
  selectKitOptions,
} from "select-kit/components/select-kit";

@pluginApiIdentifiers("subscribe-us-state-select")
@selectKitOptions({
  filterable: true,
  allowAny: false,
  translatedNone: i18n(
    "discourse_subscriptions.subscribe.cardholder_address.state"
  ),
})
@classNames("subscribe-address-state-select")
export default class SubscribeUsStateSelect extends ComboBoxComponent {
  nameProperty = "name";
  valueProperty = "value";

  @computed
  get content() {
    return [
      ["AL", "Alabama"],
      ["AK", "Alaska"],
      ["AZ", "Arizona"],
      ["AR", "Arkansas"],
      ["CA", "California"],
      ["CO", "Colorado"],
      ["CT", "Connecticut"],
      ["DE", "Delaware"],
      ["US", "District"],
      ["FL", "Florida"],
      ["GA", "Georgia"],
      ["HI", "Hawaii"],
      ["ID", "Idaho"],
      ["IL", "Illinois"],
      ["IN", "Indiana"],
      ["IA", "Iowa"],
      ["KS", "Kansas"],
      ["KY", "Kentucky"],
      ["LA", "Louisiana"],
      ["ME", "Maine"],
      ["MD", "Maryland"],
      ["MA", "Massachusetts"],
      ["MI", "Michigan"],
      ["MN", "Minnesota"],
      ["MS", "Mississippi"],
      ["MO", "Missouri"],
      ["MT", "Montana"],
      ["NE", "Nebraska"],
      ["NV", "Nevada"],
      ["NH", "New Hampshire"],
      ["NJ", "New Jersey"],
      ["NM", "New Mexico"],
      ["NY", "New York"],
      ["NC", "North Carolina"],
      ["ND", "North Dakota"],
      ["OH", "Ohio"],
      ["OK", "Oklahoma"],
      ["OR", "Oregon"],
      ["PA", "Pennsylvania"],
      ["RI", "Rhode"],
      ["SC", "South"],
      ["SD", "South"],
      ["TN", "Tennessee"],
      ["TX", "Texas"],
      ["UT", "Utah"],
      ["VT", "Vermont"],
      ["VA", "Virginia"],
      ["WA", "Washington"],
      ["WV", "West"],
      ["WI", "Wisconsin"],
      ["WY", "Wyoming"],
      ["AS", "American Samoa"],
      ["GU", "Guam"],
      ["MP", "Northern Mariana Islands"],
      ["PR", "Puerto Rico"],
      ["VI", "U.S. Virgin Islands"],
      ["UM", "U.S. Minor Outlying Islands"],
      ["MH", "Marshall Islands"],
      ["FM", "Micronesia"],
      ["PW", "Palau"],
      ["AA", "U.S. Armed Forces – Americas"],
      ["AE", "U.S. Armed Forces – Europe"],
      ["AP", "U.S. Armed Forces – Pacific"],
    ].map((arr) => {
      return { value: arr[0], name: arr[1] };
    });
  }
}
