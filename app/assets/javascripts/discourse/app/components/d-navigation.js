import Component from "@ember/component";
import FilterModeMixin from "discourse/mixins/filter-mode";
import NavItem from "discourse/models/nav-item";
import discourseComputed from "discourse-common/utils/decorators";
import { NotificationLevels } from "discourse/lib/notification-levels";
import { getOwner } from "discourse-common/lib/get-owner";
import { htmlSafe } from "@ember/template";
import { inject as service } from "@ember/service";
import { alias, equal } from "@ember/object/computed";

export default Component.extend(FilterModeMixin, {
  router: service(),
  dialog: service(),
  tagName: "",

  // Should be a `readOnly` instead but some themes/plugins still pass
  // the `categories` property into this component
  @discourseComputed("site.categoriesList")
  categories(categoriesList) {
    if (this.currentUser?.indirectly_muted_category_ids) {
      return categoriesList.filter(
        (category) =>
          !this.currentUser.indirectly_muted_category_ids.includes(category.id)
      );
    } else {
      return categoriesList;
    }
  },

  @discourseComputed("category")
  showCategoryNotifications(category) {
    return category && this.currentUser;
  },

  @discourseComputed("category.notification_level")
  categoryNotificationLevel(notificationLevel) {
    if (
      this.currentUser?.indirectly_muted_category_ids?.includes(
        this.category.id
      )
    ) {
      return NotificationLevels.MUTED;
    } else {
      return notificationLevel;
    }
  },

  // don't show tag notification menu on tag intersections
  @discourseComputed("tagNotification", "additionalTags")
  showTagNotifications(tagNotification, additionalTags) {
    return tagNotification && !additionalTags;
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
    "categoryReadOnlyBanner",
    "canCreateTopicOnTag",
    "tag.id"
  )
  createTopicButtonDisabled(
    createTopicDisabled,
    hasDraft,
    categoryReadOnlyBanner,
    canCreateTopicOnTag,
    tagId
  ) {
    if (tagId && !canCreateTopicOnTag) {
      return true;
    } else if (categoryReadOnlyBanner && !hasDraft) {
      return false;
    }
    return createTopicDisabled;
  },

  @discourseComputed("categoryReadOnlyBanner", "hasDraft")
  createTopicClass(categoryReadOnlyBanner, hasDraft) {
    let classNames = ["btn-default"];
    if (hasDraft) {
      classNames.push("open-draft");
    } else if (categoryReadOnlyBanner) {
      classNames.push("disabled");
    }
    return classNames.join(" ");
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

  @discourseComputed(
    "filterType",
    "category",
    "noSubcategories",
    "tag.id",
    "router.currentRoute.queryParams",
    "skipCategoriesNavItem"
  )
  navItems(
    filterType,
    category,
    noSubcategories,
    tagId,
    currentRouteQueryParams,
    skipCategoriesNavItem
  ) {
    return NavItem.buildList(category, {
      filterType,
      noSubcategories,
      currentRouteQueryParams,
      tagId,
      siteSettings: this.siteSettings,
      skipCategoriesNavItem,
    });
  },

  @discourseComputed("filterType")
  notCategoriesRoute(filterType) {
    return filterType !== "categories";
  },

  @discourseComputed()
  canBulk() {
    const controller = getOwner(this).lookup("controller:discovery/topics");
    return controller.canBulkSelect;
  },

  isQueryFilterMode: equal("filterMode", "filter"),
  queryString: alias("router.currentRoute.queryParams.q"),

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
        this.dialog.alert({ message: htmlSafe(this.categoryReadOnlyBanner) });
      } else {
        this.createTopic();
      }
    },
  },
});
