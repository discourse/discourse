import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import RelativeTimePicker from "discourse/components/relative-time-picker";
import icon from "discourse/helpers/d-icon";
import lazyHash from "discourse/helpers/lazy-hash";
import withEventValue from "discourse/helpers/with-event-value";
import { SEARCH_PRIORITIES } from "discourse/lib/constants";
import getUrl from "discourse/lib/get-url";
import { applyMutableValueTransformer } from "discourse/lib/transformer";
import ComboBox from "discourse/select-kit/components/combo-box";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import { i18n } from "discourse-i18n";

export default class EditCategorySettings extends Component {
  @service site;
  @service siteSettings;

  get category() {
    return this.args.category;
  }

  get form() {
    return this.args.form;
  }

  get transientData() {
    return this.args.transientData;
  }

  get emailInEnabled() {
    return this.siteSettings.email_in;
  }

  get showPositionInput() {
    return this.siteSettings.fixed_category_positions;
  }

  get isParentCategory() {
    const parentCategoryId =
      this.transientData?.parent_category_id ??
      this.category?.parent_category_id;
    return this.category?.isParent || !parentCategoryId;
  }

  get showSubcategoryListStyle() {
    return this.transientData?.show_subcategory_list && this.isParentCategory;
  }

  get isDefaultSortOrder() {
    return !this.transientData?.sort_order;
  }

  get panelClass() {
    const isActive = this.args.selectedTab === "settings" ? "active" : "";
    return `edit-category-tab edit-category-tab-settings ${isActive}`;
  }

  // Getters for transientData values
  get position() {
    return this.transientData?.position;
  }

  get numFeaturedTopics() {
    return this.transientData?.num_featured_topics;
  }

  get searchPriority() {
    return this.transientData?.search_priority;
  }

  get allowBadges() {
    return this.transientData?.allow_badges;
  }

  get topicFeaturedLinkAllowed() {
    return this.transientData?.topic_featured_link_allowed;
  }

  get navigateToFirstPostAfterRead() {
    return this.transientData?.navigate_to_first_post_after_read;
  }

  get allTopicsWiki() {
    return this.transientData?.all_topics_wiki;
  }

  get allowUnlimitedOwnerEditsOnFirstPost() {
    return this.transientData?.allow_unlimited_owner_edits_on_first_post;
  }

  get moderatingGroupIds() {
    return this.transientData?.moderating_group_ids;
  }

  get categorySetting() {
    return this.transientData?.category_setting;
  }

  get requireTopicApproval() {
    return this.categorySetting?.require_topic_approval;
  }

  get requireReplyApproval() {
    return this.categorySetting?.require_reply_approval;
  }

  get defaultSlowModeMinutes() {
    const seconds = this.transientData?.default_slow_mode_seconds;
    return seconds ? seconds / 60 : null;
  }

  get autoCloseHours() {
    return this.transientData?.auto_close_hours;
  }

  get autoCloseBasedOnLastPost() {
    return this.transientData?.auto_close_based_on_last_post;
  }

  get numAutoBumpDaily() {
    return this.categorySetting?.num_auto_bump_daily;
  }

  get autoBumpCooldownDays() {
    return this.categorySetting?.auto_bump_cooldown_days;
  }

  get defaultView() {
    return this.transientData?.default_view;
  }

  get defaultTopPeriod() {
    return this.transientData?.default_top_period;
  }

  get sortOrder() {
    return this.transientData?.sort_order;
  }

  get sortAscendingOption() {
    const sortAscending = this.transientData?.sort_ascending;
    if (sortAscending === "false") {
      return false;
    }
    if (sortAscending === "true") {
      return true;
    }
    return sortAscending;
  }

  get defaultListFilter() {
    return this.transientData?.default_list_filter;
  }

  get showSubcategoryList() {
    return this.transientData?.show_subcategory_list;
  }

  get subcategoryListStyle() {
    return this.transientData?.subcategory_list_style;
  }

  get readOnlyBanner() {
    return this.transientData?.read_only_banner;
  }

  get emailIn() {
    return this.transientData?.email_in;
  }

  get emailInAllowStrangers() {
    return this.transientData?.email_in_allow_strangers;
  }

  get mailinglistMirror() {
    return this.transientData?.mailinglist_mirror;
  }

  get availableSubcategoryListStyles() {
    return [
      { name: i18n("category.subcategory_list_styles.rows"), value: "rows" },
      {
        name: i18n(
          "category.subcategory_list_styles.rows_with_featured_topics"
        ),
        value: "rows_with_featured_topics",
      },
      {
        name: i18n("category.subcategory_list_styles.boxes"),
        value: "boxes",
      },
      {
        name: i18n(
          "category.subcategory_list_styles.boxes_with_featured_topics"
        ),
        value: "boxes_with_featured_topics",
      },
    ];
  }

  get availableViews() {
    const views = [
      { name: i18n("filters.hot.title"), value: "hot" },
      { name: i18n("filters.latest.title"), value: "latest" },
      { name: i18n("filters.top.title"), value: "top" },
    ];

    const context = {
      categoryId: this.category?.id,
      customFields: this.category?.custom_fields,
    };

    return applyMutableValueTransformer(
      "category-available-views",
      views,
      context
    );
  }

  get availableTopPeriods() {
    return ["all", "yearly", "quarterly", "monthly", "weekly", "daily"].map(
      (p) => {
        return { name: i18n(`filters.top.${p}.title`), value: p };
      }
    );
  }

  get availableListFilters() {
    return ["all", "none"].map((p) => {
      return { name: i18n(`category.list_filters.${p}`), value: p };
    });
  }

  get searchPrioritiesOptions() {
    const options = [];

    Object.entries(SEARCH_PRIORITIES).forEach((entry) => {
      const [name, value] = entry;

      options.push({
        name: i18n(`category.search_priority.options.${name}`),
        value,
      });
    });

    return options;
  }

  get availableSorts() {
    return applyMutableValueTransformer("category-sort-orders", [
      "likes",
      "op_likes",
      "views",
      "posts",
      "activity",
      "posters",
      "category",
      "created",
    ])
      .map((s) => ({ name: i18n("category.sort_options." + s), value: s }))
      .sort((a, b) => a.name.localeCompare(b.name));
  }

  get sortAscendingOptions() {
    return [
      { name: i18n("category.sort_ascending"), value: true },
      { name: i18n("category.sort_descending"), value: false },
    ];
  }

  get hiddenRelativeIntervals() {
    return ["mins"];
  }

  #updateCategorySetting(key, value) {
    this.form.set("category_setting", {
      ...this.categorySetting,
      [key]: value,
    });
  }

  @action
  onPositionChange(value) {
    this.form.set("position", value);
  }

  @action
  onNumFeaturedTopicsChange(value) {
    this.form.set("num_featured_topics", value);
  }

  @action
  onSearchPriorityChange(value) {
    this.form.set("search_priority", value);
  }

  @action
  onAllowBadgesChange(event) {
    this.form.set("allow_badges", event.target.checked);
  }

  @action
  onTopicFeaturedLinkAllowedChange(event) {
    this.form.set("topic_featured_link_allowed", event.target.checked);
  }

  @action
  onNavigateToFirstPostAfterReadChange(event) {
    this.form.set("navigate_to_first_post_after_read", event.target.checked);
  }

  @action
  onAllTopicsWikiChange(event) {
    this.form.set("all_topics_wiki", event.target.checked);
  }

  @action
  onAllowUnlimitedOwnerEditsOnFirstPostChange(event) {
    this.form.set(
      "allow_unlimited_owner_edits_on_first_post",
      event.target.checked
    );
  }

  @action
  onCategoryModeratingGroupsChange(groupIds) {
    this.form.set("moderating_group_ids", groupIds);
  }

  @action
  onRequireTopicApprovalChange(event) {
    this.#updateCategorySetting("require_topic_approval", event.target.checked);
  }

  @action
  onRequireReplyApprovalChange(event) {
    this.#updateCategorySetting("require_reply_approval", event.target.checked);
  }

  @action
  onDefaultSlowModeDurationChange(minutes) {
    let seconds = minutes ? minutes * 60 : null;
    this.form.set("default_slow_mode_seconds", seconds);
  }

  @action
  onAutoCloseDurationChange(minutes) {
    let hours = minutes ? minutes / 60 : null;
    this.form.set("auto_close_hours", hours);
  }

  @action
  onAutoCloseBasedOnLastPostChange(event) {
    this.form.set("auto_close_based_on_last_post", event.target.checked);
  }

  @action
  onNumAutoBumpDailyChange(value) {
    this.#updateCategorySetting("num_auto_bump_daily", value);
  }

  @action
  onAutoBumpCooldownDaysChange(value) {
    this.#updateCategorySetting("auto_bump_cooldown_days", value);
  }

  @action
  onDefaultViewChange(value) {
    this.form.set("default_view", value);
  }

  @action
  onDefaultTopPeriodChange(value) {
    this.form.set("default_top_period", value);
  }

  @action
  onSortOrderChange(value) {
    this.form.set("sort_order", value);
  }

  @action
  onSortAscendingChange(value) {
    this.form.set("sort_ascending", value);
  }

  @action
  onDefaultListFilterChange(value) {
    this.form.set("default_list_filter", value);
  }

  @action
  onShowSubcategoryListChange(event) {
    this.form.set("show_subcategory_list", event.target.checked);
  }

  @action
  onSubcategoryListStyleChange(value) {
    this.form.set("subcategory_list_style", value);
  }

  @action
  onReadOnlyBannerChange(value) {
    this.form.set("read_only_banner", value);
  }

  @action
  onEmailInChange(value) {
    this.form.set("email_in", value);
  }

  @action
  onEmailInAllowStrangersChange(event) {
    this.form.set("email_in_allow_strangers", event.target.checked);
  }

  @action
  onMailinglistMirrorChange(event) {
    this.form.set("mailinglist_mirror", event.target.checked);
  }

  <template>
    <div class={{this.panelClass}}>
      <section>
        {{#if this.showPositionInput}}
          <section class="field position-fields">
            <label for="category-position">
              {{i18n "category.position"}}
            </label>
            <input
              {{on "input" (withEventValue this.onPositionChange)}}
              value={{this.position}}
              type="number"
              min="0"
              id="category-position"
              class="position-input"
            />
          </section>
        {{/if}}

        {{#unless this.showPositionInput}}
          <section class="field position-disabled">
            {{htmlSafe
              (i18n
                "category.position_disabled"
                url=(getUrl
                  "/admin/site_settings/category/all_results?filter=fixed_category_positions"
                )
              )
            }}
          </section>
        {{/unless}}

        <section class="field num-featured-topics">
          <label for="category-number-featured-topics">
            {{#if this.transientData.parent_category_id}}
              {{i18n "category.subcategory_num_featured_topics"}}
            {{else}}
              {{i18n "category.num_featured_topics"}}
            {{/if}}
          </label>
          <input
            {{on "input" (withEventValue this.onNumFeaturedTopicsChange)}}
            value={{this.numFeaturedTopics}}
            type="number"
            min="1"
            id="category-number-featured-topics"
          />
        </section>

        <section class="field search-priority">
          <label>
            {{i18n "category.search_priority.label"}}
          </label>
          <div class="controls">
            <ComboBox
              @valueProperty="value"
              @id="category-search-priority"
              @content={{this.searchPrioritiesOptions}}
              @value={{this.searchPriority}}
              @onChange={{this.onSearchPriorityChange}}
              @options={{hash placementStrategy="absolute"}}
            />
          </div>
        </section>

        {{#if this.siteSettings.enable_badges}}
          <section class="field allow-badges">
            <label class="checkbox-label">
              <input
                type="checkbox"
                checked={{this.allowBadges}}
                {{on "change" this.onAllowBadgesChange}}
              />
              {{i18n "category.allow_badges_label"}}
            </label>
          </section>
        {{/if}}

        {{#if this.siteSettings.topic_featured_link_enabled}}
          <section class="field topic-featured-link-allowed">
            <div class="allowed-topic-featured-link-category">
              <label class="checkbox-label">
                <input
                  type="checkbox"
                  checked={{this.topicFeaturedLinkAllowed}}
                  {{on "change" this.onTopicFeaturedLinkAllowedChange}}
                />
                {{i18n "category.topic_featured_link_allowed"}}
              </label>
            </div>
          </section>
        {{/if}}

        <section class="field navigate-to-first-post-after-read">
          <label class="checkbox-label">
            <input
              type="checkbox"
              checked={{this.navigateToFirstPostAfterRead}}
              {{on "change" this.onNavigateToFirstPostAfterReadChange}}
            />
            {{i18n "category.navigate_to_first_post_after_read"}}
          </label>
        </section>

        <section class="field all-topics-wiki">
          <label class="checkbox-label">
            <input
              type="checkbox"
              checked={{this.allTopicsWiki}}
              {{on "change" this.onAllTopicsWikiChange}}
            />
            {{i18n "category.all_topics_wiki"}}
          </label>
        </section>

        <section class="field allow-unlimited-owner-edits-on-first-post">
          <label class="checkbox-label">
            <input
              type="checkbox"
              checked={{this.allowUnlimitedOwnerEditsOnFirstPost}}
              {{on "change" this.onAllowUnlimitedOwnerEditsOnFirstPostChange}}
            />
            {{i18n "category.allow_unlimited_owner_edits_on_first_post"}}
          </label>
        </section>
      </section>

      <section>
        <h3>{{i18n "category.settings_sections.moderation"}}</h3>
        {{#if this.siteSettings.enable_category_group_moderation}}
          <section class="field reviewable-by-group">
            <label>{{i18n "category.reviewable_by_group"}}</label>
            <GroupChooser
              @content={{this.site.groups}}
              @value={{this.moderatingGroupIds}}
              @onChange={{this.onCategoryModeratingGroupsChange}}
            />
          </section>
        {{/if}}

        <section class="field require-topic-approval">
          <label class="checkbox-label">
            <input
              type="checkbox"
              checked={{this.requireTopicApproval}}
              {{on "change" this.onRequireTopicApprovalChange}}
            />
            {{i18n "category.require_topic_approval"}}
          </label>
        </section>

        <section class="field require-reply-approval">
          <label class="checkbox-label">
            <input
              type="checkbox"
              checked={{this.requireReplyApproval}}
              {{on "change" this.onRequireReplyApprovalChange}}
            />
            {{i18n "category.require_reply_approval"}}
          </label>
        </section>

        <section class="field default-slow-mode">
          <div class="control-group">
            <label for="category-default-slow-mode">
              {{i18n "category.default_slow_mode"}}
            </label>
            <div class="category-default-slow-mode-seconds">
              <RelativeTimePicker
                @id="category-default-slow-mode"
                @durationMinutes={{this.defaultSlowModeMinutes}}
                @onChange={{this.onDefaultSlowModeDurationChange}}
              />
            </div>
          </div>
        </section>

        <section class="field auto-close">
          <div class="control-group">
            <label for="topic-auto-close">
              {{i18n "topic.auto_close.label"}}
            </label>
            <div class="category-topic-auto-close-hours">
              <RelativeTimePicker
                @id="topic-auto-close"
                @durationHours={{this.autoCloseHours}}
                @hiddenIntervals={{this.hiddenRelativeIntervals}}
                @onChange={{this.onAutoCloseDurationChange}}
              />
            </div>
            <label class="checkbox-label">
              <input
                type="checkbox"
                checked={{this.autoCloseBasedOnLastPost}}
                {{on "change" this.onAutoCloseBasedOnLastPostChange}}
              />
              {{i18n "topic.auto_close.based_on_last_post"}}
            </label>
          </div>
        </section>

        <section class="field num-auto-bump-daily">
          <label for="category-number-daily-bump">
            {{i18n "category.num_auto_bump_daily"}}
          </label>
          <input
            {{on "input" (withEventValue this.onNumAutoBumpDailyChange)}}
            value={{this.numAutoBumpDaily}}
            type="number"
            min="0"
            id="category-number-daily-bump"
          />
        </section>

        <section class="field auto-bump-cooldown-days">
          <label for="category-auto-bump-cooldown-days">
            {{i18n "category.auto_bump_cooldown_days"}}
          </label>
          <input
            {{on "input" (withEventValue this.onAutoBumpCooldownDaysChange)}}
            value={{this.autoBumpCooldownDays}}
            type="number"
            min="0"
            id="category-auto-bump-cooldown-days"
          />
        </section>
      </section>

      <section>
        <h3>{{i18n "category.settings_sections.appearance"}}</h3>

        <section class="field default-view-field">
          <label>
            {{i18n "category.default_view"}}
          </label>
          <div class="controls">
            <ComboBox
              @valueProperty="value"
              @id="category-default-view"
              @content={{this.availableViews}}
              @value={{this.defaultView}}
              @onChange={{this.onDefaultViewChange}}
              @options={{hash placementStrategy="absolute"}}
            />
          </div>
        </section>

        <section class="field default-top-period-field">
          <label>
            {{i18n "category.default_top_period"}}
          </label>
          <div class="controls">
            <ComboBox
              @valueProperty="value"
              @id="category-default-period"
              @content={{this.availableTopPeriods}}
              @value={{this.defaultTopPeriod}}
              @onChange={{this.onDefaultTopPeriodChange}}
              @options={{hash placementStrategy="absolute"}}
            />
          </div>
        </section>

        <section class="field sort-order">
          <label>
            {{i18n "category.sort_order"}}
          </label>
          <div class="controls">
            <ComboBox
              @valueProperty="value"
              @content={{this.availableSorts}}
              @value={{this.sortOrder}}
              @options={{hash none="category.sort_options.default"}}
              @onChange={{this.onSortOrderChange}}
            />
            {{#unless this.isDefaultSortOrder}}
              <ComboBox
                @valueProperty="value"
                @content={{this.sortAscendingOptions}}
                @value={{this.sortAscendingOption}}
                @options={{hash
                  none="category.sort_options.default"
                  placementStrategy="absolute"
                }}
                @onChange={{this.onSortAscendingChange}}
              />
            {{/unless}}
          </div>
        </section>

        <section class="field default-filter">
          <label>
            {{i18n "category.default_list_filter"}}
          </label>
          <div class="controls">
            <ComboBox
              @id="category-default-filter"
              @valueProperty="value"
              @content={{this.availableListFilters}}
              @value={{this.defaultListFilter}}
              @onChange={{this.onDefaultListFilterChange}}
            />
          </div>
        </section>

        {{#if this.isParentCategory}}
          <section class="field show-subcategory-list-field">
            <label class="checkbox-label">
              <input
                type="checkbox"
                checked={{this.showSubcategoryList}}
                {{on "change" this.onShowSubcategoryListChange}}
              />
              {{i18n "category.show_subcategory_list"}}
            </label>
          </section>
        {{/if}}

        {{#if this.showSubcategoryListStyle}}
          <section class="field subcategory-list-style-field">
            <label>
              {{i18n "category.subcategory_list_style"}}
            </label>
            <ComboBox
              @valueProperty="value"
              @id="subcategory-list-style"
              @content={{this.availableSubcategoryListStyles}}
              @value={{this.subcategoryListStyle}}
              @onChange={{this.onSubcategoryListStyleChange}}
              @options={{hash placementStrategy="absolute"}}
            />
          </section>
        {{/if}}

        <section class="field category-read-only-banner">
          <label for="read-only-message">{{i18n
              "category.read_only_banner"
            }}</label>
          <input
            type="text"
            id="read-only-message"
            value={{this.readOnlyBanner}}
            {{on "input" (withEventValue this.onReadOnlyBannerChange)}}
          />
        </section>
      </section>

      <section>
        <h3>{{i18n "category.settings_sections.email"}}</h3>

        {{#if this.emailInEnabled}}
          <section class="field category-email-in">
            <label for="category-email-in">
              {{icon "envelope"}}
              {{i18n "category.email_in"}}
            </label>
            <input
              type="text"
              id="category-email-in"
              value={{this.emailIn}}
              {{on "input" (withEventValue this.onEmailInChange)}}
              class="email-in"
            />
          </section>

          <section class="field email-in-allow-strangers">
            <label class="checkbox-label">
              <input
                type="checkbox"
                checked={{this.emailInAllowStrangers}}
                {{on "change" this.onEmailInAllowStrangersChange}}
              />
              {{i18n "category.email_in_allow_strangers"}}
            </label>
          </section>

          <section class="field mailinglist-mirror">
            <label class="checkbox-label">
              <input
                type="checkbox"
                checked={{this.mailinglistMirror}}
                {{on "change" this.onMailinglistMirrorChange}}
              />
              {{i18n "category.mailinglist_mirror"}}
            </label>
          </section>

          <span>
            <PluginOutlet
              @name="category-email-in"
              @connectorTagName="div"
              @outletArgs={{lazyHash category=this.category}}
            />
          </span>
        {{/if}}

        {{#unless this.emailInEnabled}}
          <section class="field email-in-disabled">
            {{htmlSafe
              (i18n
                "category.email_in_disabled"
                setting_url=(getUrl
                  "/admin/site_settings/category/all_results?filter=email_in"
                )
              )
            }}
          </section>
        {{/unless}}
      </section>

      <section>
        <PluginOutlet
          @name="category-custom-settings"
          @outletArgs={{lazyHash category=this.category}}
        />
      </section>
    </div>
  </template>
}
