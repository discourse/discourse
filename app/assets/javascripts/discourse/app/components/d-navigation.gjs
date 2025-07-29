import { tracked } from "@glimmer/tracking";
import Component from "@ember/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { tagName } from "@ember-decorators/component";
import { and, gt } from "truth-helpers";
import BreadCrumbs from "discourse/components/bread-crumbs";
import BulkSelectToggle from "discourse/components/bulk-select-toggle";
import CategoryNotificationsTracking from "discourse/components/category-notifications-tracking";
import CreateTopicButton from "discourse/components/create-topic-button";
import DButton from "discourse/components/d-button";
import NavigationBar from "discourse/components/navigation-bar";
import PluginOutlet from "discourse/components/plugin-outlet";
import TagNotificationsTracking from "discourse/components/tag-notifications-tracking";
import TopicDismissButtons from "discourse/components/topic-dismiss-buttons";
import lazyHash from "discourse/helpers/lazy-hash";
import { setting } from "discourse/lib/computed";
import discourseComputed from "discourse/lib/decorators";
import { filterTypeForMode } from "discourse/lib/filter-mode";
import { NotificationLevels } from "discourse/lib/notification-levels";
import { applyValueTransformer } from "discourse/lib/transformer";
import NavItem from "discourse/models/nav-item";
import CategoriesAdminDropdown from "select-kit/components/categories-admin-dropdown";

@tagName("")
export default class DNavigation extends Component {
  @service router;
  @service dialog;
  @service site;

  @tracked filterMode;

  @setting("fixed_category_positions") fixedCategoryPositions;

  get createTopicLabel() {
    const defaultKey = "topic.create";

    return applyValueTransformer(
      "create-topic-label",
      this.site.desktopView ? defaultKey : "",
      { site: this.site, defaultKey }
    );
  }

  get showBulkSelectInNavControls() {
    const enableOnDesktop = applyValueTransformer(
      "bulk-select-in-nav-controls",
      false,
      { site: this.site }
    );

    return (
      (this.site.mobileView || enableOnDesktop) &&
      this.notCategoriesRoute &&
      this.canBulkSelect
    );
  }

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
    "categoryReadOnlyBanner",
    "canCreateTopicOnTag",
    "tag.id"
  )
  createTopicButtonDisabled(
    createTopicDisabled,
    categoryReadOnlyBanner,
    canCreateTopicOnTag,
    tagId
  ) {
    if (tagId && !canCreateTopicOnTag) {
      return true;
    } else if (categoryReadOnlyBanner) {
      return false;
    }
    return createTopicDisabled;
  }

  @discourseComputed("categoryReadOnlyBanner")
  createTopicClass(categoryReadOnlyBanner) {
    let classNames = ["btn-default"];
    if (categoryReadOnlyBanner) {
      classNames.push("disabled");
    }
    return classNames.join(" ");
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
    if (this.categoryReadOnlyBanner) {
      this.dialog.alert({ message: htmlSafe(this.categoryReadOnlyBanner) });
    } else {
      this.createTopic();
    }
  }

  <template>
    <BreadCrumbs
      @categories={{this.categories}}
      @category={{this.category}}
      @noSubcategories={{this.noSubcategories}}
      @tag={{this.tag}}
      @additionalTags={{this.additionalTags}}
    />

    <PluginOutlet
      @name="after-breadcrumbs"
      @outletArgs={{lazyHash
        categories=this.categories
        category=this.category
        tag=this.tag
        additionalTags=this.additionalTags
      }}
    />

    {{#unless this.additionalTags}}
      {{! nav bar doesn't work with tag intersections }}
      <NavigationBar
        @navItems={{this.navItems}}
        @filterMode={{this.filterMode}}
        @category={{this.category}}
        @tag={{this.tag}}
      />
    {{/unless}}

    <div class="navigation-controls">
      {{#if this.showBulkSelectInNavControls}}
        <BulkSelectToggle @bulkSelectHelper={{@bulkSelectHelper}} />
      {{/if}}

      <TopicDismissButtons
        @position="top"
        @selectedTopics={{@bulkSelectHelper.selected}}
        @model={{@model}}
        @showResetNew={{@showResetNew}}
        @showDismissRead={{@showDismissRead}}
        @resetNew={{@resetNew}}
        @dismissRead={{@dismissRead}}
      />

      {{#if this.showCategoryAdmin}}
        {{#if this.fixedCategoryPositions}}
          <CategoriesAdminDropdown
            @onChange={{this.selectCategoryAdminDropdownAction}}
            @options={{hash triggerOnChangeOnTab=false}}
          />
        {{else}}
          <DButton
            @action={{this.createCategory}}
            @icon="plus"
            @label={{if
              this.site.mobileView
              "categories.category"
              "category.create"
            }}
            class="btn-default"
            id="create-category"
          />
        {{/if}}
      {{/if}}

      {{#if (and this.category this.showCategoryEdit)}}
        <DButton
          @action={{this.editCategory}}
          @icon="wrench"
          @title="category.edit_title"
          class="btn-default edit-category"
        />
      {{/if}}

      {{#if this.tag}}
        {{#if this.showToggleInfo}}
          <DButton
            @icon={{if this.currentUser.staff "wrench" "circle-info"}}
            @ariaLabel="tagging.info"
            @action={{this.toggleInfo}}
            id="show-tag-info"
            class="btn-default"
          />
        {{/if}}
      {{/if}}

      <PluginOutlet
        @name="before-create-topic-button"
        @outletArgs={{lazyHash
          canCreateTopic=this.canCreateTopic
          createTopicDisabled=this.createTopicDisabled
          createTopicLabel=this.createTopicLabel
          additionalTags=this.additionalTags
          category=this.category
          tag=this.tag
        }}
      />

      <CreateTopicButton
        @canCreateTopic={{this.canCreateTopic}}
        @action={{this.clickCreateTopicButton}}
        @disabled={{this.createTopicButtonDisabled}}
        @label={{this.createTopicLabel}}
        @btnClass={{this.createTopicClass}}
        @canCreateTopicOnTag={{this.canCreateTopicOnTag}}
        @showDrafts={{if (gt this.draftCount 0) true false}}
      />

      <PluginOutlet
        @name="after-create-topic-button"
        @outletArgs={{lazyHash
          canCreateTopic=this.canCreateTopic
          createTopicDisabled=this.createTopicDisabled
          createTopicLabel=this.createTopicLabel
          category=this.category
          tag=this.tag
        }}
      />

      {{#if this.category}}
        {{#unless this.tag}}
          {{! don't show category notification menu on tag pages }}
          {{#if this.showCategoryNotifications}}
            {{#unless this.category.deleted}}
              <CategoryNotificationsTracking
                @levelId={{this.categoryNotificationLevel}}
                @showFullTitle={{false}}
                @showCaret={{false}}
                @onChange={{this.changeCategoryNotificationLevel}}
              />
            {{/unless}}
          {{/if}}
        {{/unless}}
      {{/if}}

      {{#if this.tag}}
        {{#unless this.category}}
          {{! don't show tag notification menu on category pages }}
          {{#if this.showTagNotifications}}
            <TagNotificationsTracking
              @onChange={{this.changeTagNotificationLevel}}
              @levelId={{this.tagNotification.notification_level}}
            />
          {{/if}}
        {{/unless}}
      {{/if}}
    </div>
  </template>
}
