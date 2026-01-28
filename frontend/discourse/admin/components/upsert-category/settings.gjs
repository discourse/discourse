import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import RelativeTimePicker from "discourse/components/relative-time-picker";
import lazyHash from "discourse/helpers/lazy-hash";
import withEventValue from "discourse/helpers/with-event-value";
import { SEARCH_PRIORITIES } from "discourse/lib/constants";
import getUrl from "discourse/lib/get-url";
import { applyMutableValueTransformer } from "discourse/lib/transformer";
import ComboBox from "discourse/select-kit/components/combo-box";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import { i18n } from "discourse-i18n";

export default class UpsertCategorySettings extends Component {
  @service site;
  @service siteSettings;

  get emailInEnabled() {
    return this.siteSettings.email_in;
  }

  get showPositionInput() {
    return this.siteSettings.fixed_category_positions;
  }

  get isParentCategory() {
    const parentCategoryId =
      this.args.transientData?.parent_category_id ??
      this.args.category.parent_category_id;
    return this.args.category.isParent || !parentCategoryId;
  }

  get panelClass() {
    const isActive = this.args.selectedTab === "settings" ? "active" : "";
    return `edit-category-tab edit-category-tab-settings ${isActive}`;
  }

  @cached
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

  @cached
  get availableViews() {
    const views = [
      { name: i18n("filters.hot.title"), value: "hot" },
      { name: i18n("filters.latest.title"), value: "latest" },
      { name: i18n("filters.top.title"), value: "top" },
    ];

    const context = {
      categoryId: this.args.category.id,
      customFields: this.args.category.custom_fields,
    };

    return applyMutableValueTransformer(
      "category-available-views",
      views,
      context
    );
  }

  @cached
  get availableTopPeriods() {
    return ["all", "yearly", "quarterly", "monthly", "weekly", "daily"].map(
      (p) => {
        return { name: i18n(`filters.top.${p}.title`), value: p };
      }
    );
  }

  @cached
  get availableListFilters() {
    return ["all", "none"].map((p) => {
      return { name: i18n(`category.list_filters.${p}`), value: p };
    });
  }

  @cached
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

  @cached
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

  get sortAscendingOption() {
    const sortAscending = this.args.transientData?.sort_ascending;
    if (sortAscending === "false") {
      return false;
    }
    if (sortAscending === "true") {
      return true;
    }
    return sortAscending;
  }

  @cached
  get sortAscendingOptions() {
    return [
      { name: i18n("category.sort_ascending"), value: true },
      { name: i18n("category.sort_descending"), value: false },
    ];
  }

  get hiddenRelativeIntervals() {
    return ["mins"];
  }

  get moderatingGroupIds() {
    return this.args.transientData?.moderating_group_ids;
  }

  get autoCloseHours() {
    return this.args.transientData?.auto_close_hours;
  }

  get defaultSlowModeMinutes() {
    const seconds = this.args.transientData?.default_slow_mode_seconds;
    return seconds ? seconds / 60 : null;
  }

  get categorySetting() {
    return this.args.transientData?.category_setting;
  }

  get requireTopicApproval() {
    return this.categorySetting?.require_topic_approval;
  }

  get requireReplyApproval() {
    return this.categorySetting?.require_reply_approval;
  }

  get autoCloseBasedOnLastPost() {
    return this.args.transientData?.auto_close_based_on_last_post;
  }

  get numAutoBumpDaily() {
    return this.categorySetting?.num_auto_bump_daily;
  }

  get autoBumpCooldownDays() {
    return this.categorySetting?.auto_bump_cooldown_days;
  }

  @action
  onAutoCloseDurationChange(minutes) {
    let hours = minutes ? minutes / 60 : null;
    this.args.form.set("auto_close_hours", hours);
  }

  @action
  onDefaultSlowModeDurationChange(minutes) {
    let seconds = minutes ? minutes * 60 : null;
    this.args.form.set("default_slow_mode_seconds", seconds);
  }

  #updateCategorySetting(key, value) {
    this.args.form.set("category_setting", {
      ...this.categorySetting,
      [key]: value,
    });
  }

  @action
  onCategoryModeratingGroupsChange(groupIds) {
    this.args.form.set("moderating_group_ids", groupIds);
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
  onAutoCloseBasedOnLastPostChange(event) {
    this.args.form.set("auto_close_based_on_last_post", event.target.checked);
  }

  @action
  onNumAutoBumpDailyChange(value) {
    this.#updateCategorySetting("num_auto_bump_daily", value);
  }

  @action
  onAutoBumpCooldownDaysChange(value) {
    this.#updateCategorySetting("auto_bump_cooldown_days", value);
  }

  <template>
    <div class={{this.panelClass}}>
      {{! This field is removed from edit-category-general when the UC is active }}
      {{#if this.siteSettings.enable_simplified_category_creation}}
        <@form.Field
          @name="slug"
          @title={{i18n "category.slug"}}
          @format="large"
          as |field|
        >
          <field.Input
            placeholder={{i18n "category.slug_placeholder"}}
            @maxlength="255"
          />
        </@form.Field>
      {{/if}}

      {{#if this.showPositionInput}}
        <@form.Field
          @name="position"
          @title={{i18n "category.position"}}
          @format="large"
          as |field|
        >
          <field.Input type="number" min="0" />
        </@form.Field>
      {{/if}}

      <@form.Field
        @name="num_featured_topics"
        @title={{if
          @category.parent_category_id
          (i18n "category.subcategory_num_featured_topics")
          (i18n "category.num_featured_topics")
        }}
        @format="large"
        as |field|
      >
        <field.Input type="number" min="1" />
      </@form.Field>

      <@form.Field
        @name="search_priority"
        @title={{i18n "category.search_priority.label"}}
        @format="large"
        as |field|
      >
        <field.Custom>
          <ComboBox
            @valueProperty="value"
            @id="category-search-priority"
            @content={{this.searchPrioritiesOptions}}
            @value={{field.value}}
            @onChange={{field.set}}
            @options={{hash placementStrategy="absolute"}}
          />
        </field.Custom>
      </@form.Field>

      {{#if this.siteSettings.enable_badges}}
        <@form.Field
          @name="allow_badges"
          @title={{i18n "category.allow_badges_label"}}
          @format="large"
          as |field|
        >
          <field.Checkbox />
        </@form.Field>
      {{/if}}

      {{#if this.siteSettings.topic_featured_link_enabled}}
        <@form.Field
          @name="topic_featured_link_allowed"
          @title={{i18n "category.topic_featured_link_allowed"}}
          @format="large"
          as |field|
        >
          <field.Checkbox />
        </@form.Field>
      {{/if}}

      <@form.Field
        @name="navigate_to_first_post_after_read"
        @title={{i18n "category.navigate_to_first_post_after_read"}}
        @format="large"
        as |field|
      >
        <field.Checkbox />
      </@form.Field>

      <@form.Field
        @name="all_topics_wiki"
        @title={{i18n "category.all_topics_wiki"}}
        @format="large"
        as |field|
      >
        <field.Checkbox />
      </@form.Field>

      <@form.Field
        @name="allow_unlimited_owner_edits_on_first_post"
        @title={{i18n "category.allow_unlimited_owner_edits_on_first_post"}}
        @format="large"
        as |field|
      >
        <field.Checkbox />
      </@form.Field>

      <@form.Section @title={{i18n "category.settings_sections.moderation"}}>
        {{#if this.siteSettings.enable_category_group_moderation}}
          <@form.Container @title={{i18n "category.reviewable_by_group"}}>
            <GroupChooser
              @content={{this.site.groups}}
              @value={{this.moderatingGroupIds}}
              @onChange={{this.onCategoryModeratingGroupsChange}}
            />
          </@form.Container>
        {{/if}}

        <@form.Container>
          <label class="checkbox-label">
            <input
              type="checkbox"
              checked={{this.requireTopicApproval}}
              {{on "change" this.onRequireTopicApprovalChange}}
            />
            {{i18n "category.require_topic_approval"}}
          </label>
        </@form.Container>

        <@form.Container>
          <label class="checkbox-label">
            <input
              type="checkbox"
              checked={{this.requireReplyApproval}}
              {{on "change" this.onRequireReplyApprovalChange}}
            />
            {{i18n "category.require_reply_approval"}}
          </label>
        </@form.Container>

        <@form.Container @title={{i18n "category.default_slow_mode"}}>
          <RelativeTimePicker
            @id="category-default-slow-mode"
            @durationMinutes={{this.defaultSlowModeMinutes}}
            @onChange={{this.onDefaultSlowModeDurationChange}}
          />
        </@form.Container>

        <@form.Container @title={{i18n "topic.auto_close.label"}}>
          <RelativeTimePicker
            @id="topic-auto-close"
            @durationHours={{this.autoCloseHours}}
            @hiddenIntervals={{this.hiddenRelativeIntervals}}
            @onChange={{this.onAutoCloseDurationChange}}
          />
          <label class="checkbox-label">
            <input
              type="checkbox"
              checked={{this.autoCloseBasedOnLastPost}}
              {{on "change" this.onAutoCloseBasedOnLastPostChange}}
            />
            {{i18n "topic.auto_close.based_on_last_post"}}
          </label>
        </@form.Container>

        <@form.Container @title={{i18n "category.num_auto_bump_daily"}}>
          <input
            {{on "input" (withEventValue this.onNumAutoBumpDailyChange)}}
            value={{this.numAutoBumpDaily}}
            type="number"
            min="0"
            id="category-number-daily-bump"
          />
        </@form.Container>

        <@form.Container @title={{i18n "category.auto_bump_cooldown_days"}}>
          <input
            {{on "input" (withEventValue this.onAutoBumpCooldownDaysChange)}}
            value={{this.autoBumpCooldownDays}}
            type="number"
            min="0"
            id="category-auto-bump-cooldown-days"
          />
        </@form.Container>
      </@form.Section>

      <@form.Section @title={{i18n "category.settings_sections.email"}}>
        {{#if this.emailInEnabled}}
          <@form.Field
            @name="email_in"
            @title={{i18n "category.email_in"}}
            @format="large"
            as |field|
          >
            <field.Input @maxlength="255" />
          </@form.Field>

          <@form.Field
            @name="email_in_allow_strangers"
            @title={{i18n "category.email_in_allow_strangers"}}
            @format="large"
            as |field|
          >
            <field.Checkbox />
          </@form.Field>

          <@form.Field
            @name="mailinglist_mirror"
            @title={{i18n "category.mailinglist_mirror"}}
            @format="large"
            as |field|
          >
            <field.Checkbox />
          </@form.Field>

          <PluginOutlet
            @name="category-email-in"
            @connectorTagName="div"
            @outletArgs={{lazyHash category=@category}}
          />
        {{else}}
          <@form.Alert @type="info">
            {{htmlSafe
              (i18n
                "category.email_in_disabled"
                setting_url=(getUrl
                  "/admin/site_settings/category/all_results?filter=email_in"
                )
              )
            }}
          </@form.Alert>
        {{/if}}
      </@form.Section>

      <PluginOutlet
        @name="category-custom-settings"
        @outletArgs={{lazyHash category=@category}}
      />
    </div>
  </template>
}
