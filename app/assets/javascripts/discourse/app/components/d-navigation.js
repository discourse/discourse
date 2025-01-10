import { tracked } from "@glimmer/tracking";
import Component from "@ember/component";
import { action } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { tagName } from "@ember-decorators/component";
import { setting } from "discourse/lib/computed";
import { filterTypeForMode } from "discourse/lib/filter-mode";
import { NotificationLevels } from "discourse/lib/notification-levels";
import NavItem from "discourse/models/nav-item";
import discourseComputed from "discourse-common/utils/decorators";

const DRAFTS_MENU_LIMIT = 4;

@tagName("")
export default class DNavigation extends Component {
  @service router;
  @service dialog;

  @tracked filterMode;

  @setting("fixed_category_positions") fixedCategoryPositions;

  createTopicLabel = "topic.create";

  @dependentKeyCompat
  get filterType() {
    return filterTypeForMode(this.filterMode);
  }

  // Should be a `readOnly` instead but some themes/plugins still pass
  // the `categories` property into this component
  @discourseComputed()
  categories() {
    let categories = this.site.categoriesList;

    if (!this.siteSettings.allow_uncategorized_topics) {
      categories = categories.filter(
        (category) => category.id !== this.site.uncategorized_category_id
      );
    }

    if (this.currentUser?.indirectly_muted_category_ids) {
      categories = categories.filter(
        (category) =>
          !this.currentUser.indirectly_muted_category_ids.includes(category.id)
      );
    }

    return categories;
  }

  @discourseComputed("category")
  showCategoryNotifications(category) {
    return category && this.currentUser;
  }

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
  }

  // don't show tag notification menu on tag intersections
  @discourseComputed("tagNotification", "additionalTags")
  showTagNotifications(tagNotification, additionalTags) {
    return tagNotification && !additionalTags;
  }

  @discourseComputed("category", "createTopicDisabled")
  categoryReadOnlyBanner(category, createTopicDisabled) {
    if (category && this.currentUser && createTopicDisabled) {
      return category.read_only_banner;
    }
  }

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
  }

  @discourseComputed("categoryReadOnlyBanner", "hasDraft")
  createTopicClass(categoryReadOnlyBanner, hasDraft) {
    let classNames = ["btn-default"];
    if (hasDraft) {
      classNames.push("open-draft");
    } else if (categoryReadOnlyBanner) {
      classNames.push("disabled");
    }
    return classNames.join(" ");
  }

  @discourseComputed("draftCount")
  showDraftsMenu(draftCount) {
    return draftCount > 0;
  }

  @discourseComputed("draftCount")
  otherDraftsCount(draftCount) {
    return draftCount > DRAFTS_MENU_LIMIT ? draftCount - DRAFTS_MENU_LIMIT : 0;
  }

  get draftLimit() {
    return DRAFTS_MENU_LIMIT;
  }

  @discourseComputed("category.can_edit")
  showCategoryEdit(canEdit) {
    return canEdit;
  }

  @discourseComputed("additionalTags", "category", "tag.id")
  showToggleInfo(additionalTags, category, tagId) {
    return !additionalTags && !category && tagId !== "none";
  }

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
  }

  @discourseComputed("filterType")
  notCategoriesRoute(filterType) {
    return filterType !== "categories";
  }

  @action
  async changeTagNotificationLevel(notificationLevel) {
    const response = await this.tagNotification.update({
      notification_level: notificationLevel,
    });

    const payload = response.responseJson;

    this.tagNotification.set("notification_level", notificationLevel);

    this.currentUser.setProperties({
      watched_tags: payload.watched_tags,
      watching_first_post_tags: payload.watching_first_post_tags,
      tracked_tags: payload.tracked_tags,
      muted_tags: payload.muted_tags,
      regular_tags: payload.regular_tags,
    });
  }

  @action
  changeCategoryNotificationLevel(notificationLevel) {
    this.category.setNotification(notificationLevel);
  }

  @action
  selectCategoryAdminDropdownAction(actionId) {
    switch (actionId) {
      case "create":
        this.createCategory();
        break;
      case "reorder":
        this.reorderCategories();
        break;
    }
  }

  @action
  clickCreateTopicButton() {
    if (this.categoryReadOnlyBanner && !this.hasDraft) {
      this.dialog.alert({ message: htmlSafe(this.categoryReadOnlyBanner) });
    } else {
      this.createTopic();
    }
  }
}
