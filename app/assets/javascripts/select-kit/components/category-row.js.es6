import { reads, bool } from "@ember/object/computed";
import SelectKitRowComponent from "select-kit/components/select-kit/select-kit-row";
import Category from "discourse/models/category";
import { categoryBadgeHTML } from "discourse/helpers/category-link";
import { isEmpty, isNone } from "@ember/utils";
import { computed } from "@ember/object";
import { setting } from "discourse/lib/computed";

export default SelectKitRowComponent.extend({
  layoutName: "select-kit/templates/components/category-row",
  classNames: ["category-row"],
  hideParentCategory: bool("selectKit.options.hideParentCategory"),
  allowUncategorized: bool("selectKit.options.allowUncategorized"),
  categoryLink: bool("selectKit.options.categoryLink"),
  countSubcategories: bool("selectKit.options.countSubcategories"),
  allowUncategorizedTopics: setting("allow_uncategorized_topics"),

  displayCategoryDescription: computed(
    "selectKit.options.displayCategoryDescription",
    function() {
      const option = this.selectKit.options.displayCategoryDescription;
      if (isNone(option)) {
        return true;
      }

      return option;
    }
  ),

  title: computed("descriptionText", "description", "categoryName", function() {
    return this.descriptionText || this.description || this.categoryName;
  }),

  categoryName: reads("category.name"),

  categoryDescription: reads("category.description"),

  categoryDescriptionText: reads("category.description_text"),

  category: computed("rowValue", "rowName", function() {
    if (isEmpty(this.rowValue)) {
      const uncat = Category.findUncategorized();
      if (uncat && uncat.name === this.rowName) {
        return uncat;
      }
    } else {
      return Category.findById(parseInt(this.rowValue, 10));
    }
  }),

  badgeForCategory: computed("category", "parentCategory", function() {
    return categoryBadgeHTML(this.category, {
      link: this.categoryLink,
      allowUncategorized:
        this.allowUncategorizedTopics || this.allowUncategorized,
      hideParent: !!this.parentCategory
    }).htmlSafe();
  }),

  badgeForParentCategory: computed("parentCategory", function() {
    return categoryBadgeHTML(this.parentCategory, {
      link: this.categoryLink,
      allowUncategorized:
        this.allowUncategorizedTopics || this.allowUncategorized,
      recursive: true
    }).htmlSafe();
  }),

  parentCategory: computed("parentCategoryId", function() {
    return Category.findById(this.parentCategoryId);
  }),

  hasParentCategory: bool("parentCategoryId"),

  parentCategoryId: reads("category.parent_category_id"),

  categoryTotalTopicCount: reads("category.totalTopicCount"),

  categoryTopicCount: reads("category.topic_count"),

  topicCount: computed(
    "categoryTotalTopicCount",
    "categoryTopicCount",
    "countSubcategories",
    function() {
      return this.countSubcategories
        ? this.categoryTotalTopicCount
        : this.categoryTopicCount;
    }
  ),

  shouldDisplayDescription: computed(
    "displayCategoryDescription",
    "categoryDescription",
    function() {
      return (
        this.displayCategoryDescription &&
        this.categoryDescription &&
        this.categoryDescription !== "null"
      );
    }
  ),

  descriptionText: computed("categoryDescriptionText", function() {
    if (this.categoryDescriptionText) {
      return this._formatDescription(this.categoryDescriptionText);
    }
  }),

  description: computed("categoryDescription", function() {
    if (this.categoryDescription) {
      return this._formatDescription(this.categoryDescription);
    }
  }),

  _formatDescription(description) {
    const limit = 200;
    return `${description.substr(0, limit)}${
      description.length > limit ? "&hellip;" : ""
    }`;
  }
});
