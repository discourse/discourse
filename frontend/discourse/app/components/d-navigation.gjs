/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { hash } from "@ember/helper";
import { action, computed } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { service } from "@ember/service";
import { tagName } from "@ember-decorators/component";
import BreadCrumbs from "discourse/components/bread-crumbs";
import BulkSelectToggle from "discourse/components/bulk-select-toggle";
import CategoryNotificationsTracking from "discourse/components/category-notifications-tracking";
import CreateTopicButton from "discourse/components/create-topic-button";
import NavigationBar from "discourse/components/navigation-bar";
import NavigationOptionsMenu from "discourse/components/navigation-options-menu";
import PluginOutlet from "discourse/components/plugin-outlet";
import TagInfoButton from "discourse/components/tag-info-button";
import TagNotificationsTracking from "discourse/components/tag-notifications-tracking";
import TopicDismissButtons from "discourse/components/topic-dismiss-buttons";
import lazyHash from "discourse/helpers/lazy-hash";
import { filterTypeForMode } from "discourse/lib/filter-mode";
import { NotificationLevels } from "discourse/lib/notification-levels";
import {
  applyBehaviorTransformer,
  applyValueTransformer,
} from "discourse/lib/transformer";
import NavItem from "discourse/models/nav-item";
import CategoriesAdminDropdown from "discourse/select-kit/components/categories-admin-dropdown";
import TagCategoryAdminDropdown from "discourse/select-kit/components/tag-category-admin-dropdown";
import DButton from "discourse/ui-kit/d-button";

@tagName("")
export default class DNavigation extends Component {
  @service router;
  @service site;
  @service siteSettings;
  @service currentUser;
  @service discovery;
  @service mobileTabBar;

  #topicCreator = {
    canCreate: () => this.canCreateTopic,
    create: () => this.clickCreateTopicButton(),
  };

  init() {
    super.init(...arguments);
    this.discovery.topicCreator = this.#topicCreator;
  }

  willDestroy() {
    super.willDestroy(...arguments);

    // The next list may already have registered its own
    if (this.discovery.topicCreator === this.#topicCreator) {
      this.discovery.topicCreator = null;
    }
  }

  @computed("siteSettings.fixed_category_positions")
  get fixedCategoryPositions() {
    return this.siteSettings.fixed_category_positions;
  }

  @computed("category", "site.shared_drafts_category_id", "site.desktopView")
  get createTopicLabel() {
    const defaultKey = "topic.create";
    let value = this.site.desktopView ? defaultKey : "";

    if (
      value === defaultKey &&
      this.site.shared_drafts_category_id &&
      this.category?.id === this.site.shared_drafts_category_id
    ) {
      value = "topic.create_shared_draft";
    }

    return applyValueTransformer("create-topic-label", value, {
      site: this.site,
      defaultKey,
      category: this.category,
      currentUser: this.currentUser,
    });
  }

  @computed("category")
  get createTopicIcon() {
    const defaultIcon = "far-pen-to-square";

    return applyValueTransformer("create-topic-icon", defaultIcon, {
      site: this.site,
      defaultIcon,
      category: this.category,
      currentUser: this.currentUser,
    });
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
  @computed()
  get categories() {
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

  @computed("category")
  get showCategoryNotifications() {
    return this.category && this.currentUser;
  }

  @computed("category.notification_level")
  get categoryNotificationLevel() {
    if (
      this.currentUser?.indirectly_muted_category_ids?.includes(
        this.category.id
      )
    ) {
      return NotificationLevels.MUTED;
    } else {
      return this.category?.notification_level;
    }
  }

  // don't show tag notification menu on tag intersections
  @computed("tagNotification", "additionalTags")
  get showTagNotifications() {
    return this.tagNotification && !this.additionalTags;
  }

  @computed("category", "createTopicDisabled")
  get categoryReadOnlyBanner() {
    if (this.category && this.currentUser && this.createTopicDisabled) {
      return this.category.read_only_banner;
    }
  }

  @computed("category.can_edit")
  get showCategoryEdit() {
    return this.category?.can_edit;
  }

  @computed("tag", "tag.name", "additionalTags", "currentUser.canEditTags")
  get showTagEdit() {
    return (
      this.tag &&
      this.tag.name !== "none" &&
      !this.additionalTags &&
      this.currentUser?.canEditTags
    );
  }

  @computed("toggleTagInfo", "tag", "tag.name", "additionalTags", "category")
  get showTagInfoButton() {
    return (
      this.toggleTagInfo &&
      this.tag &&
      this.tag.name !== "none" &&
      !this.additionalTags &&
      !this.category
    );
  }

  @computed(
    "category.can_edit",
    "tag",
    "tag.name",
    "additionalTags",
    "currentUser.canEditTags"
  )
  get showCombinedAdminDropdown() {
    return this.category?.can_edit && this.showTagEdit;
  }

  @computed(
    "filterType",
    "category",
    "noSubcategories",
    "tag",
    "router.currentRoute.queryParams",
    "skipCategoriesNavItem"
  )
  get navItems() {
    const items = NavItem.buildList(this.category, {
      filterType: this.filterType,
      noSubcategories: this.noSubcategories,
      currentRouteQueryParams: this.router?.currentRoute?.queryParams,
      tag: this.tag,
      siteSettings: this.siteSettings,
      skipCategoriesNavItem: this.skipCategoriesNavItem,
    });

    return applyValueTransformer("navigation-items", items, {
      category: this.category,
      tag: this.tag,
      filterType: this.filterType,
    });
  }

  // With the tab bar, dismissing sits in the options beside the list's views,
  // which tag intersections go without
  get dismissInOptions() {
    return this.mobileTabBar.enabled && !this.additionalTags;
  }

  @computed("showResetNew", "filterType", "currentUser.unified_new_enabled")
  get showNewDismissCombo() {
    return (
      this.showResetNew &&
      this.filterType === "new" &&
      this.currentUser.unified_new_enabled
    );
  }

  @computed("filterType")
  get notCategoriesRoute() {
    return this.filterType !== "categories";
  }

  // The tab bar's lists show the dropdowns everywhere but the category list,
  // which they'd only filter down to itself
  get showBreadCrumbs() {
    return !(
      this.mobileTabBar.enabled &&
      !this.notCategoriesRoute &&
      !this.category
    );
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
  handleTagCategoryAdmin(actionId) {
    switch (actionId) {
      case "editCategory":
        this.editCategory();
        break;
      case "editTag":
        this.router.transitionTo(
          "tag.edit.tab",
          this.tag.slug,
          this.tag.id,
          "general"
        );
        break;
    }
  }

  @action
  clickCreateTopicButton() {
    applyBehaviorTransformer(
      "create-topic-button-click",
      () => this.createTopic(),
      { category: this.category, tag: this.tag }
    );
  }

  @action
  editTag() {
    this.router.transitionTo(
      "tag.edit.tab",
      this.tag.slug,
      this.tag.id,
      "general"
    );
  }

  <template>
    {{#if this.showBreadCrumbs}}
      <BreadCrumbs
        @additionalTags={{this.additionalTags}}
        @categories={{this.categories}}
        @category={{this.category}}
        @noSubcategories={{this.noSubcategories}}
        @tag={{this.tag}}
      />
    {{/if}}

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
      {{#if this.mobileTabBar.enabled}}
        {{! Within the thumb's reach, in the strip the tab bar keeps for a
          section's views; it's gone while the bar is hidden }}
        {{#if this.mobileTabBar.viewsSlot}}
          {{#in-element this.mobileTabBar.viewsSlot insertBefore=null}}
            <NavigationBar
              @category={{this.category}}
              @countAsBadge={{true}}
              @filterMode={{this.filterMode}}
              @navItems={{this.navItems}}
              @tag={{this.tag}}
            />
            {{! Admins can fix category positions to reorder; others reorder
              only once they're fixed }}
            <NavigationOptionsMenu
              @bulkSelectHelper={{@bulkSelectHelper}}
              @canChangeCategorySettings={{and
                this.showCategoryAdmin
                this.currentUser.admin
              }}
              @canReorderCategories={{and
                this.showCategoryAdmin
                (or this.currentUser.admin this.fixedCategoryPositions)
              }}
              @dismissRead={{@dismissRead}}
              @model={{@model}}
              @reorderCategories={{this.reorderCategories}}
              @resetNew={{@resetNew}}
              @showBulkSelect={{this.showBulkSelectInNavControls}}
              @showDismissRead={{@showDismissRead}}
              @showNewDismissCombo={{this.showNewDismissCombo}}
              @showResetNew={{@showResetNew}}
            />
          {{/in-element}}
        {{/if}}
      {{else}}
        <NavigationBar
          @category={{this.category}}
          @filterMode={{this.filterMode}}
          @navItems={{this.navItems}}
          @tag={{this.tag}}
        />
      {{/if}}
    {{/unless}}

    <div class="navigation-controls">
      {{! With the tab bar, these sit in the options menu beside the list's views }}
      {{#if
        (and this.showBulkSelectInNavControls (not this.mobileTabBar.enabled))
      }}
        <BulkSelectToggle @bulkSelectHelper={{@bulkSelectHelper}} />
      {{/if}}

      {{#unless this.dismissInOptions}}
        <TopicDismissButtons
          @dismissRead={{@dismissRead}}
          @model={{@model}}
          @position="top"
          @resetNew={{@resetNew}}
          @selectedTopics={{@bulkSelectHelper.selected}}
          @showDismissRead={{@showDismissRead}}
          @showNewDismissCombo={{this.showNewDismissCombo}}
          @showResetNew={{@showResetNew}}
        />
      {{/unless}}

      {{#if this.showCategoryAdmin}}
        {{#if this.mobileTabBar.enabled}}
          {{! The row is the list's own, so creating takes it; the list's
            settings sit in the options beside its views }}
          <DButton
            class="btn-default"
            id="create-category"
            @action={{this.createCategory}}
            @icon="plus"
            @label="category.create"
          />
        {{else if this.fixedCategoryPositions}}
          <CategoriesAdminDropdown
            @onChange={{this.selectCategoryAdminDropdownAction}}
            @options={{hash triggerOnChangeOnTab=false}}
          />
        {{else}}
          <DButton
            class="btn-default"
            id="create-category"
            @action={{this.createCategory}}
            @icon="plus"
            @label={{if
              this.site.mobileView
              "categories.category"
              "category.create"
            }}
          />
        {{/if}}
      {{/if}}

      {{#if this.showCombinedAdminDropdown}}
        <TagCategoryAdminDropdown
          @category={{this.category}}
          @onChange={{this.handleTagCategoryAdmin}}
          @options={{hash triggerOnChangeOnTab=false}}
          @tag={{this.tag}}
        />
      {{else}}
        {{#if (and this.category this.showCategoryEdit)}}
          <DButton
            class="btn-default edit-category"
            @action={{this.editCategory}}
            @icon="wrench"
            @title="category.edit_title"
          />
        {{/if}}

        {{#if this.showTagEdit}}
          <DButton
            class="btn-default"
            id="edit-tag"
            @action={{this.editTag}}
            @ariaLabel="tagging.edit"
            @icon="wrench"
            @title="tagging.edit"
          />
        {{/if}}
      {{/if}}

      {{#if this.showTagInfoButton}}
        <TagInfoButton
          @active={{@showTagInfo}}
          @loading={{@loadingTagInfo}}
          @toggleInfo={{@toggleTagInfo}}
        />
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

      {{! The tab bar's create button starts topics and opens drafts }}
      {{#unless this.mobileTabBar.enabled}}
        <CreateTopicButton
          @action={{this.clickCreateTopicButton}}
          @btnTypeClass={{if
            this.siteSettings.modernize_foundation_theme
            "btn-primary"
          }}
          @canCreateTopic={{this.canCreateTopic}}
          @icon={{this.createTopicIcon}}
          @label={{this.createTopicLabel}}
          @showDrafts={{if (gt this.draftCount 0) true false}}
        />
      {{/unless}}

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
                @onChange={{this.changeCategoryNotificationLevel}}
                @showCaret={{false}}
                @showFullTitle={{false}}
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
              @levelId={{this.tagNotification.notification_level}}
              @onChange={{this.changeTagNotificationLevel}}
            />
          {{/if}}
        {{/unless}}
      {{/if}}
    </div>
  </template>
}
