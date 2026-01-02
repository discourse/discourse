import { classNames } from "@ember-decorators/component";
import MultiSelectComponent from "discourse/select-kit/components/multi-select";
import { HOUSE_AD_ROUTES } from "../lib/house-ad-routes";

@classNames("route-selector")
export default class HouseAdsRouteSelector extends MultiSelectComponent {
  filterable = true;
  filterPlaceholder = "admin.adplugin.house_ads.filter_placeholder";
  allowCreate = false;
  allowAny = false;
  valueAttribute = "id";
  nameProperty = "name";

  get content() {
    return HOUSE_AD_ROUTES;
  }
}
