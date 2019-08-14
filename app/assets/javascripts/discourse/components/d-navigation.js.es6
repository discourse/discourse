import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  router: Ember.inject.service(),
  persistedQueryParams: null,

  tagName: "",

  @computed("category")
  showCategoryNotifications(category) {
    return category && this.currentUser;
  },

  @computed()
  categories() {
    return this.site.get("categoriesList");
  },

  @computed("hasDraft")
  createTopicLabel(hasDraft) {
    return hasDraft ? "topic.open_draft" : "topic.create";
  },

  @computed("category.can_edit")
  showCategoryEdit: canEdit => canEdit,

  @computed("filterMode", "category", "noSubcategories")
  navItems(filterMode, category, noSubcategories) {
    // we don't want to show the period in the navigation bar since it's in a dropdown
    if (filterMode.indexOf("top/") === 0) {
      filterMode = filterMode.replace("top/", "");
    }

    let params;
    const currentRouteQueryParams = this.get("router.currentRoute.queryParams");
    if (this.persistedQueryParams && currentRouteQueryParams) {
      const currentKeys = Object.keys(currentRouteQueryParams);
      const discoveryKeys = Object.keys(this.persistedQueryParams);
      const supportedKeys = currentKeys.filter(
        i => discoveryKeys.indexOf(i) > 0
      );
      params = supportedKeys.reduce((object, key) => {
        object[key] = currentRouteQueryParams[key];
        return object;
      }, {});
    }

    return Discourse.NavItem.buildList(category, {
      filterMode,
      noSubcategories,
      persistedQueryParams: params
    });
  }
});
