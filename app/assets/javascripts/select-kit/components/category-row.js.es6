import SelectKitRowComponent from "select-kit/components/select-kit/select-kit-row";
import computed from "ember-addons/ember-computed-decorators";
import Category from "discourse/models/category";
import { categoryBadgeHTML } from "discourse/helpers/category-link";

export default SelectKitRowComponent.extend({
  layoutName: "select-kit/templates/components/category-row",
  classNames: "category-row",

  hideParentCategory: Ember.computed.bool("options.hideParentCategory"),
  allowUncategorized: Ember.computed.bool("options.allowUncategorized"),
  categoryLink: Ember.computed.bool("options.categoryLink"),

  @computed("options.displayCategoryDescription")
  displayCategoryDescription(displayCategoryDescription) {
    if (Ember.isNone(displayCategoryDescription)) {
      return true;
    }

    return displayCategoryDescription;
  },

  @computed("descriptionText", "description", "category.name")
  title(descriptionText, description, name) {
    return descriptionText || description || name;
  },

  @computed("computedContent.value", "computedContent.name")
  category(value, name) {
    if (Ember.isEmpty(value)) {
      const uncat = Category.findUncategorized();
      if (uncat && uncat.get("name") === name) {
        return uncat;
      }
    } else {
      return Category.findById(parseInt(value, 10));
    }
  },

  @computed("category", "parentCategory")
  badgeForCategory(category, parentCategory) {
    return categoryBadgeHTML(category, {
      link: this.get("categoryLink"),
      allowUncategorized: this.get("allowUncategorized"),
      hideParent: parentCategory ? true : false
    }).htmlSafe();
  },

  @computed("parentCategory")
  badgeForParentCategory(parentCategory) {
    return categoryBadgeHTML(parentCategory, {
      link: this.get("categoryLink"),
      allowUncategorized: this.get("allowUncategorized")
    }).htmlSafe();
  },

  @computed("parentCategoryid")
  parentCategory(parentCategoryId) {
    return Category.findById(parentCategoryId);
  },

  @computed("parentCategoryid")
  hasParentCategory(parentCategoryid) {
    return !Ember.isNone(parentCategoryid);
  },

  @computed("category")
  parentCategoryid(category) {
    return category.get("parent_category_id");
  },

  @computed(
    "category.totalTopicCount",
    "category.topic_count",
    "options.countSubcategories"
  )
  topicCount(totalCount, topicCount, countSubcats) {
    return `&times; ${countSubcats ? totalCount : topicCount}`.htmlSafe();
  },

  @computed("displayCategoryDescription", "category.description")
  shouldDisplayDescription(displayCategoryDescription, description) {
    return displayCategoryDescription && description && description !== "null";
  },

  @computed("category.description_text")
  descriptionText(description) {
    if (description) {
      return this._formatCategoryDescription(description);
    }
  },

  @computed("category.description")
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
