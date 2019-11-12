import { bool } from "@ember/object/computed";
import { isEmpty } from "@ember/utils";
import SelectKitRowComponent from "select-kit/components/select-kit/select-kit-row";
import discourseComputed from "discourse-common/utils/decorators";
import Category from "discourse/models/category";
import { categoryBadgeHTML } from "discourse/helpers/category-link";
import { isNone } from "@ember/utils";

export default SelectKitRowComponent.extend({
  layoutName: "select-kit/templates/components/category-row",
  classNames: "category-row",

  hideParentCategory: bool("options.hideParentCategory"),
  allowUncategorized: bool("options.allowUncategorized"),
  categoryLink: bool("options.categoryLink"),

  @discourseComputed("options.displayCategoryDescription")
  displayCategoryDescription(displayCategoryDescription) {
    if (isNone(displayCategoryDescription)) {
      return true;
    }

    return displayCategoryDescription;
  },

  @discourseComputed("descriptionText", "description", "category.name")
  title(descriptionText, description, name) {
    return descriptionText || description || name;
  },

  @discourseComputed("computedContent.value", "computedContent.name")
  category(value, name) {
    if (isEmpty(value)) {
      const uncat = Category.findUncategorized();
      if (uncat && uncat.get("name") === name) {
        return uncat;
      }
    } else {
      return Category.findById(parseInt(value, 10));
    }
  },

  @discourseComputed("category", "parentCategory")
  badgeForCategory(category, parentCategory) {
    return categoryBadgeHTML(category, {
      link: this.categoryLink,
      allowUncategorized: this.allowUncategorized,
      hideParent: parentCategory ? true : false
    }).htmlSafe();
  },

  @discourseComputed("parentCategory")
  badgeForParentCategory(parentCategory) {
    return categoryBadgeHTML(parentCategory, {
      link: this.categoryLink,
      allowUncategorized: this.allowUncategorized
    }).htmlSafe();
  },

  @discourseComputed("parentCategoryid")
  parentCategory(parentCategoryId) {
    return Category.findById(parentCategoryId);
  },

  @discourseComputed("parentCategoryid")
  hasParentCategory(parentCategoryid) {
    return !isNone(parentCategoryid);
  },

  @discourseComputed("category")
  parentCategoryid(category) {
    return category.get("parent_category_id");
  },

  @discourseComputed(
    "category.totalTopicCount",
    "category.topic_count",
    "options.countSubcategories"
  )
  topicCount(totalCount, topicCount, countSubcats) {
    return countSubcats ? totalCount : topicCount;
  },

  @discourseComputed("displayCategoryDescription", "category.description")
  shouldDisplayDescription(displayCategoryDescription, description) {
    return displayCategoryDescription && description && description !== "null";
  },

  @discourseComputed("category.description_text")
  descriptionText(descriptionText) {
    if (descriptionText) {
      return this._formatCategoryDescription(descriptionText);
    }
  },

  @discourseComputed("category.description")
  description(description) {
    if (description) {
      return this._formatCategoryDescription(description);
    }
  },

  _formatCategoryDescription(description) {
    return `${description.substr(0, 200)}${
      description.length > 200 ? "&hellip;" : ""
    }`;
  }
});
