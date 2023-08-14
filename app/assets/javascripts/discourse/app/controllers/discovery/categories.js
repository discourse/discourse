import { inject as controller } from "@ember/controller";
import { reads } from "@ember/object/computed";
import DiscoveryController from "discourse/controllers/discovery";
import { action } from "@ember/object";
import { dasherize } from "@ember/string";
import discourseComputed from "discourse-common/utils/decorators";

const subcategoryStyleComponentNames = {
  rows: "categories_only",
  rows_with_featured_topics: "categories_with_featured_topics",
  boxes: "categories_boxes",
  boxes_with_featured_topics: "categories_boxes_with_topics",
};

const mobileCompatibleViews = [
  "categories_with_featured_topics",
  "subcategories_with_featured_topics",
];

export default class CategoriesController extends DiscoveryController {
  @controller discovery;

  // this makes sure the composer isn't scoping to a specific category
  category = null;

  @reads("currentUser.staff") canEdit;

  @discourseComputed
  isCategoriesRoute() {
    return this.router.currentRouteName === "discovery.categories";
  }

  @discourseComputed("model.parentCategory")
  categoryPageStyle(parentCategory) {
    let style = this.siteSettings.desktop_category_page_style;

    if (this.site.mobileView && !mobileCompatibleViews.includes(style)) {
      style = mobileCompatibleViews[0];
    }

    if (parentCategory) {
      style =
        subcategoryStyleComponentNames[
          parentCategory.get("subcategory_list_style")
        ] || style;
    }

    const componentName =
      parentCategory &&
      (style === "categories_and_latest_topics" ||
        style === "categories_and_latest_topics_created_date")
        ? "categories_only"
        : style;
    return dasherize(componentName);
  }

  @action
  showInserted(event) {
    event?.preventDefault();
    const tracker = this.topicTrackingState;
    // Move inserted into topics
    this.model.loadBefore(tracker.get("newIncoming"), true);
    tracker.resetTracking();
  }

  @action
  refresh() {
    this.send("triggerRefresh");
  }
}
