import discourseComputed from "discourse-common/utils/decorators";
import NavItem from "discourse/models/nav-item";
import { inject as service } from "@ember/service";
import Component from "@ember/component";
import FilterModeMixin from "discourse/mixins/filter-mode";
import bootbox from "bootbox";

export default Component.extend(FilterModeMixin, {
  router: service(),

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
  showCategoryEdit: (canEdit) => canEdit,

  @discourseComputed("additionalTags", "category", "tag.id")
  showToggleInfo(additionalTags, category, tagId) {
    return !additionalTags && !category && tagId !== "none";
  },

  @discourseComputed("filterType", "category", "noSubcategories", "tag.id")
  navItems(filterType, category, noSubcategories, tagId) {
    const currentRouteQueryParams = this.get("router.currentRoute.queryParams");

    return NavItem.buildList(category, {
      filterType,
      noSubcategories,
      currentRouteQueryParams,
      tagId,
      siteSettings: this.siteSettings,
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
    },

    toggleTagInfo() {
      return this.toggleProperty("showInfo");
    },

    changeTagNotificationLevel(notificationLevel) {
      this.tagNotification
        .update({ notification_level: notificationLevel })
        .then((response) => {
          this.currentUser.set(
            "muted_tag_ids",
            this.currentUser.calculateMutedIds(
              notificationLevel,
              response.responseJson.tag_id,
              "muted_tag_ids"
            )
          );
        });
    },
  },
});
