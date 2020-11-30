import Category from "discourse/models/category";
import Component from "@ember/component";
import I18n from "I18n";
import discourseComputed from "discourse-common/utils/decorators";
import { sort } from "@ember/object/computed";

export default Component.extend({
  classNameBindings: [
    ":tags-list",
    ":tag-list",
    "categoryClass",
    "tagGroupNameClass",
  ],

  isPrivateMessage: false,
  sortedTags: sort("tags", "sortProperties"),

  @discourseComputed("titleKey")
  title(titleKey) {
    return titleKey && I18n.t(titleKey);
  },

  @discourseComputed("categoryId")
  category(categoryId) {
    return categoryId && Category.findById(categoryId);
  },

  @discourseComputed("category.fullSlug")
  categoryClass(slug) {
    return slug && `tag-list-${slug}`;
  },

  @discourseComputed("tagGroupName")
  tagGroupNameClass(groupName) {
    if (groupName) {
      groupName = groupName
        .replace(/\s+/g, "-")
        .replace(/[!\"#$%&'\(\)\*\+,\.\/:;<=>\?\@\[\\\]\^`\{\|\}~]/g, "")
        .toLowerCase();
      return groupName && `tag-group-${groupName}`;
    }
  },
});
