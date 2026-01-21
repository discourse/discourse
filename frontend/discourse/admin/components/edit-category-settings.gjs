import { Input } from "@ember/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { and, empty } from "@ember/object/computed";
import { htmlSafe } from "@ember/template";
import { buildCategoryPanel } from "discourse/admin/components/edit-category-panel";
import PluginOutlet from "discourse/components/plugin-outlet";
import RelativeTimePicker from "discourse/components/relative-time-picker";
import lazyHash from "discourse/helpers/lazy-hash";
import withEventValue from "discourse/helpers/with-event-value";
import { setting } from "discourse/lib/computed";
import { SEARCH_PRIORITIES } from "discourse/lib/constants";
import discourseComputed from "discourse/lib/decorators";
import getUrl from "discourse/lib/get-url";
import { applyMutableValueTransformer } from "discourse/lib/transformer";
import ComboBox from "discourse/select-kit/components/combo-box";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import { i18n } from "discourse-i18n";

export default class EditCategorySettings extends buildCategoryPanel(
  "settings"
) {
  @setting("email_in") emailInEnabled;
  @setting("fixed_category_positions") showPositionInput;

  @and("category.show_subcategory_list", "isParentCategory")
  showSubcategoryListStyle;
  @empty("category.sort_order") isDefaultSortOrder;

  @discourseComputed(
    "category.isParent",
    "category.parent_category_id",
    "transientData.parent_category_id"
  )
  isParentCategory(isParent, parentCategoryId, transientParentCategoryId) {
    return isParent || !(parentCategoryId || transientParentCategoryId);
  }

  @discourseComputed
  availableSubcategoryListStyles() {
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

  @discourseComputed("category.id", "category.custom_fields")
  availableViews(categoryId, customFields) {
    const views = [
      { name: i18n("filters.hot.title"), value: "hot" },
      { name: i18n("filters.latest.title"), value: "latest" },
      { name: i18n("filters.top.title"), value: "top" },
    ];

    const context = {
      categoryId,
      customFields,
    };

    return applyMutableValueTransformer(
      "category-available-views",
      views,
      context
    );
  }

  @discourseComputed
  availableTopPeriods() {
    return ["all", "yearly", "quarterly", "monthly", "weekly", "daily"].map(
      (p) => {
        return { name: i18n(`filters.top.${p}.title`), value: p };
      }
    );
  }

  @discourseComputed
  availableListFilters() {
    return ["all", "none"].map((p) => {
      return { name: i18n(`category.list_filters.${p}`), value: p };
    });
  }

  @discourseComputed
  searchPrioritiesOptions() {
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

  @discourseComputed
  availableSorts() {
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

  @discourseComputed("category.sort_ascending")
  sortAscendingOption(sortAscending) {
    if (sortAscending === "false") {
      return false;
    }
    if (sortAscending === "true") {
      return true;
    }
    return sortAscending;
  }

  @discourseComputed
  sortAscendingOptions() {
    return [
      { name: i18n("category.sort_ascending"), value: true },
      { name: i18n("category.sort_descending"), value: false },
    ];
  }

  @discourseComputed
  hiddenRelativeIntervals() {
    return ["mins"];
  }

  @action
  onAutoCloseDurationChange(minutes) {
    let hours = minutes ? minutes / 60 : null;
    this.set("category.auto_close_hours", hours);
  }

  @action
  onDefaultSlowModeDurationChange(minutes) {
    let seconds = minutes ? minutes * 60 : null;
    this.set("category.default_slow_mode_seconds", seconds);
  }

  @action
  onCategoryModeratingGroupsChange(groupIds) {
    this.set("category.moderating_group_ids", groupIds);
  }

  <template>
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
            @value={{@category.moderating_group_ids}}
            @onChange={{this.onCategoryModeratingGroupsChange}}
          />
        </@form.Container>
      {{/if}}

      <@form.Container>
        <label class="checkbox-label">
          <Input
            @type="checkbox"
            @checked={{@category.category_setting.require_topic_approval}}
          />
          {{i18n "category.require_topic_approval"}}
        </label>
      </@form.Container>

      <@form.Container>
        <label class="checkbox-label">
          <Input
            @type="checkbox"
            @checked={{@category.category_setting.require_reply_approval}}
          />
          {{i18n "category.require_reply_approval"}}
        </label>
      </@form.Container>

      <@form.Container @title={{i18n "category.default_slow_mode"}}>
        <RelativeTimePicker
          @id="category-default-slow-mode"
          @durationMinutes={{@category.defaultSlowModeMinutes}}
          @onChange={{this.onDefaultSlowModeDurationChange}}
        />
      </@form.Container>

      <@form.Container @title={{i18n "topic.auto_close.label"}}>
        <RelativeTimePicker
          @id="topic-auto-close"
          @durationHours={{@category.auto_close_hours}}
          @hiddenIntervals={{this.hiddenRelativeIntervals}}
          @onChange={{this.onAutoCloseDurationChange}}
        />
        <label class="checkbox-label">
          <Input
            @type="checkbox"
            @checked={{@category.auto_close_based_on_last_post}}
          />
          {{i18n "topic.auto_close.based_on_last_post"}}
        </label>
      </@form.Container>

      <@form.Container @title={{i18n "category.num_auto_bump_daily"}}>
        <input
          {{on
            "input"
            (withEventValue
              (fn (mut @category.category_setting.num_auto_bump_daily))
            )
          }}
          value={{@category.category_setting.num_auto_bump_daily}}
          type="number"
          min="0"
          id="category-number-daily-bump"
        />
      </@form.Container>

      <@form.Container @title={{i18n "category.auto_bump_cooldown_days"}}>
        <input
          {{on
            "input"
            (withEventValue
              (fn (mut @category.category_setting.auto_bump_cooldown_days))
            )
          }}
          value={{@category.category_setting.auto_bump_cooldown_days}}
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
  </template>
}
