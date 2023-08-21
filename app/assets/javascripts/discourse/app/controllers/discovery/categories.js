import Controller from "@ember/controller";
import { inject as service } from "@ember/service";
import { reads } from "@ember/object/computed";
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

// Todo: make this return a component class instead of string
export function categoriesComponent({ site, siteSettings, parentCategory }) {
  let style = siteSettings.desktop_category_page_style;

  if (site.mobileView && !mobileCompatibleViews.includes(style)) {
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

export default class CategoriesController extends Controller {
  @service router;

  @reads("currentUser.staff") canEdit;

  @discourseComputed
  isCategoriesRoute() {
    return this.router.currentRouteName === "discovery.categories";
  }

  @discourseComputed("model.parentCategory")
  categoryPageStyle(parentCategory) {
    return categoriesComponent({
      site: this.site,
      siteSettings: this.siteSettings,
      parentCategory,
    });
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
