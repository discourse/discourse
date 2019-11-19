import discourseComputed from "discourse-common/utils/decorators";
import NavItem from "discourse/models/nav-item";
import { inject as service } from "@ember/service";
import Component from "@ember/component";

export default Component.extend({
  router: service(),
  persistedQueryParams: null,

  tagName: "",

  @discourseComputed("category")
  showCategoryNotifications(category) {
    return category && this.currentUser;
  },

  @discourseComputed()
  categories() {
    return this.site.get("categoriesList");
  },

  @discourseComputed("hasDraft")
  createTopicLabel(hasDraft) {
    return hasDraft ? "topic.open_draft" : "topic.create";
  },

  @discourseComputed("category.can_edit")
  showCategoryEdit: canEdit => canEdit,

  @discourseComputed("filterMode", "category", "noSubcategories")
  navItems(filterMode, category, noSubcategories) {
    // we don't want to show the period in the navigation bar since it's in a dropdown
    if (filterMode.indexOf("top/") === 0) {
      filterMode = "top";
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

    return NavItem.buildList(category, {
      filterMode,
      noSubcategories,
      persistedQueryParams: params
    });
  }
});
