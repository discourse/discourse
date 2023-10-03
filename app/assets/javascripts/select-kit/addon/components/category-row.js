import { bool, reads } from "@ember/object/computed";
import { isEmpty, isNone } from "@ember/utils";
import Category from "discourse/models/category";
import SelectKitRowComponent from "select-kit/components/select-kit/select-kit-row";
import { categoryBadgeHTML } from "discourse/helpers/category-link";
import { computed } from "@ember/object";
import { setting } from "discourse/lib/computed";
import { htmlSafe } from "@ember/template";

export default SelectKitRowComponent.extend({
  classNames: ["category-row"],
  hideParentCategory: bool("selectKit.options.hideParentCategory"),
  allowUncategorized: bool("selectKit.options.allowUncategorized"),
  categoryLink: bool("selectKit.options.categoryLink"),
  countSubcategories: bool("selectKit.options.countSubcategories"),
  allowUncategorizedTopics: setting("allow_uncategorized_topics"),

  displayCategoryDescription: computed(
    "selectKit.options.displayCategoryDescription",
    function () {
      const option = this.selectKit.options.displayCategoryDescription;
      if (isNone(option)) {
        return true;
      }

      return option;
    }
  ),

  title: computed("categoryName", function () {
    if (this.category) {
      return this.categoryName;
    }
  }),
  categoryName: reads("category.name"),

  categoryDescriptionText: reads("category.description_text"),

  category: computed("rowValue", "rowName", function () {
    if (isEmpty(this.rowValue)) {
      const uncategorized = Category.findUncategorized();
      if (uncategorized && uncategorized.name === this.rowName) {
        return uncategorized;
      }
    } else {
      return Category.findById(parseInt(this.rowValue, 10));
    }
  }),

  badgeForCategory: computed("category", "parentCategory", function () {
    return htmlSafe(
      categoryBadgeHTML(this.category, {
        link: this.categoryLink,
        allowUncategorized:
          this.allowUncategorizedTopics || this.allowUncategorized,
        hideParent: !!this.parentCategory,
        topicCount: this.topicCount,
      })
    );
  }),

  badgeForParentCategory: computed("parentCategory", function () {
    return htmlSafe(
      categoryBadgeHTML(this.parentCategory, {
        link: this.categoryLink,
        allowUncategorized:
          this.allowUncategorizedTopics || this.allowUncategorized,
        recursive: true,
      })
    );
  }),

  parentCategory: computed("parentCategoryId", function () {
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
    function () {
      return this.countSubcategories
        ? this.categoryTotalTopicCount
        : this.categoryTopicCount;
    }
  ),

  shouldDisplayDescription: computed(
    "displayCategoryDescription",
    "categoryDescriptionText",
    function () {
      return (
        this.displayCategoryDescription &&
        this.categoryDescriptionText &&
        this.categoryDescriptionText !== "null"
      );
    }
  ),

  descriptionText: computed("categoryDescriptionText", function () {
    if (this.categoryDescriptionText) {
      return this._formatDescription(this.categoryDescriptionText);
    }
  }),

  _formatDescription(description) {
    const limit = 200;
    return `${description.slice(0, limit)}${
      description.length > limit ? "&hellip;" : ""
    }`;
  },
});
