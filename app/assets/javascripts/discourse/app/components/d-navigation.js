import discourseComputed from "discourse-common/utils/decorators";
import NavItem from "discourse/models/nav-item";
import { inject as service } from "@ember/service";
import Component from "@ember/component";
import FilterModeMixin from "discourse/mixins/filter-mode";

export default Component.extend(FilterModeMixin, {
  router: service(),
  persistedQueryParams: null,

  tagName: "",

  @discourseComputed("category")
  showCategoryNotifications(category) {
    return category && this.currentUser;
  },

  @discourseComputed("category", "createTopicDisabled")
  categoryReadOnlyBanner(category, createTopicDisabled) {
    if (category && this.currentUser && createTopicDisabled) {
      return category.read_only_banner;
    }
  },

  @discourseComputed(
    "createTopicDisabled",
    "hasDraft",
    "categoryReadOnlyBanner"
  )
  createTopicButtonDisabled(
    createTopicDisabled,
    hasDraft,
    categoryReadOnlyBanner
  ) {
    if (categoryReadOnlyBanner && !hasDraft) {
      return false;
    }
    return createTopicDisabled;
  },

  @discourseComputed("categoryReadOnlyBanner", "hasDraft")
  createTopicClass(categoryReadOnlyBanner, hasDraft) {
    if (categoryReadOnlyBanner && !hasDraft) {
      return "btn-default disabled";
    } else {
      return "btn-default";
    }
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

  @discourseComputed("filterType", "category", "noSubcategories")
  navItems(filterType, category, noSubcategories) {
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
      filterType,
      noSubcategories,
      persistedQueryParams: params
    });
  },

  actions: {
    changeCategoryNotificationLevel(notificationLevel) {
      this.category.setNotification(notificationLevel);
    },

    selectCategoryAdminDropdownAction(actionId) {
      switch (actionId) {
        case "create":
          this.createCategory();
          break;
        case "reorder":
          this.reorderCategories();
          break;
      }
    },

    clickCreateTopicButton() {
      if (this.categoryReadOnlyBanner && !this.hasDraft) {
        bootbox.alert(this.categoryReadOnlyBanner);
      } else {
        this.createTopic();
      }
    }
  }
});
