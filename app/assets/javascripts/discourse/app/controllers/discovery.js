import { inject as service } from "@ember/service";
import { equal } from "@ember/object/computed";
import Controller from "@ember/controller";
import Category from "discourse/models/category";

export default class DiscoveryController extends Controller {
  @service router;

  @equal("router.currentRouteName", "discovery.categories")
  viewingCategoriesList;

  showMoreUrl(period) {
    let url = "",
      category = this.category;

    if (category) {
      url = `/c/${Category.slugFor(category)}/${category.id}${
        this.noSubcategories ? "/none" : ""
      }/l`;
    }

    url += "/top";

    const urlSearchParams = new URLSearchParams();

    for (const [key, value] of Object.entries(
      this.router.currentRoute.queryParams
    )) {
      if (typeof value !== "undefined") {
        urlSearchParams.set(key, value);
      }
    }

    urlSearchParams.set("period", period);

    return `${url}?${urlSearchParams.toString()}`;
  }
}
