import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  classNameBindings: [":tag-list", "categoryClass"],

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
  }
});
