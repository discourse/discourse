import discourseComputed from "discourse-common/utils/decorators";
import { reads } from "@ember/object/computed";
import { inject } from "@ember/controller";
import DiscoveryController from "discourse/controllers/discovery";
import { dasherize } from "@ember/string";

const subcategoryStyleComponentNames = {
  rows: "categories_only",
  rows_with_featured_topics: "categories_with_featured_topics",
  boxes: "categories_boxes",
  boxes_with_featured_topics: "categories_boxes_with_topics"
};

export default DiscoveryController.extend({
  discovery: inject(),

  // this makes sure the composer isn't scoping to a specific category
  category: null,

  canEdit: reads("currentUser.staff"),

  @discourseComputed("model.categories.[].featuredTopics.length")
  latestTopicOnly() {
    return (
      this.get("model.categories").find(
        c => c.get("featuredTopics.length") > 1
      ) === undefined
    );
  },

  @discourseComputed("model.parentCategory")
  categoryPageStyle(parentCategory) {
    let style = this.site.mobileView
      ? "categories_with_featured_topics"
      : this.siteSettings.desktop_category_page_style;

    if (parentCategory) {
      style =
        subcategoryStyleComponentNames[
          parentCategory.get("subcategory_list_style")
        ] || style;
    }

    const componentName =
      parentCategory && style === "categories_and_latest_topics"
        ? "categories_only"
        : style;
    return dasherize(componentName);
  },
  actions: {
    refresh() {
      this.send("triggerRefresh");
    }
  }
});
