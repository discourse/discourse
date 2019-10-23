import Component from "@ember/component";
import computed from "ember-addons/ember-computed-decorators";

export default Component.extend({
  classNameBindings: [":tag-list", "categoryClass", "tagGroupNameClass"],

  isPrivateMessage: false,
  sortedTags: Ember.computed.sort("tags", "sortProperties"),

  @computed("titleKey")
  title(titleKey) {
    return titleKey && I18n.t(titleKey);
  },

  @computed("categoryId")
  category(categoryId) {
    return categoryId && Discourse.Category.findById(categoryId);
  },

  @computed("category.fullSlug")
  categoryClass(slug) {
    return slug && `tag-list-${slug}`;
  },

  @computed("tagGroupName")
  tagGroupNameClass(groupName) {
    if (groupName) {
      groupName = groupName
        .replace(/\s+/g, "-")
        .replace(/[!\"#$%&'\(\)\*\+,\.\/:;<=>\?\@\[\\\]\^`\{\|\}~]/g, "")
        .toLowerCase();
      return groupName && `tag-group-${groupName}`;
    }
  }
});
