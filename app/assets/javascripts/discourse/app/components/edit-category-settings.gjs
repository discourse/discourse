import { Input } from "@ember/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { and, empty } from "@ember/object/computed";
import { buildCategoryPanel } from "discourse/components/edit-category-panel";
import PluginOutlet from "discourse/components/plugin-outlet";
import RelativeTimePicker from "discourse/components/relative-time-picker";
import TextField from "discourse/components/text-field";
import icon from "discourse/helpers/d-icon";
import getUrl from "discourse/helpers/get-url";
import htmlSafe from "discourse/helpers/html-safe";
import lazyHash from "discourse/helpers/lazy-hash";
import withEventValue from "discourse/helpers/with-event-value";
import { setting } from "discourse/lib/computed";
import { SEARCH_PRIORITIES } from "discourse/lib/constants";
import discourseComputed from "discourse/lib/decorators";
import { applyMutableValueTransformer } from "discourse/lib/transformer";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";
import GroupChooser from "select-kit/components/group-chooser";

const categorySortCriteria = [];
export function addCategorySortCriteria(criteria) {
  categorySortCriteria.push(criteria);
}

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
    return [
      "likes",
      "op_likes",
      "views",
      "posts",
      "activity",
      "posters",
      "category",
      "created",
    ]
      .concat(categorySortCriteria)
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
    <section>
      {{#if this.showPositionInput}}
        <section class="field position-fields">
          <label for="category-position">
            {{i18n "category.position"}}
          </label>
          <input
            {{on "input" (withEventValue (fn (mut this.category.position)))}}
            value={{this.category.position}}
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
          {{#if this.category.parent_category_id}}
            {{i18n "category.subcategory_num_featured_topics"}}
          {{else}}
            {{i18n "category.num_featured_topics"}}
          {{/if}}
        </label>
        <input
          {{on
            "input"
            (withEventValue (fn (mut this.category.num_featured_topics)))
          }}
          value={{this.category.num_featured_topics}}
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
            @value={{this.category.search_priority}}
            @onChange={{fn (mut this.category.search_priority)}}
            @options={{hash placementStrategy="absolute"}}
          />
        </div>
      </section>

      {{#if this.siteSettings.enable_badges}}
        <section class="field allow-badges">
          <label class="checkbox-label">
            <Input @type="checkbox" @checked={{this.category.allow_badges}} />
            {{i18n "category.allow_badges_label"}}
          </label>
        </section>
      {{/if}}

      {{#if this.siteSettings.topic_featured_link_enabled}}
        <section class="field topic-featured-link-allowed">
          <div class="allowed-topic-featured-link-category">
            <label class="checkbox-label">
              <Input
                @type="checkbox"
                @checked={{this.category.topic_featured_link_allowed}}
              />
              {{i18n "category.topic_featured_link_allowed"}}
            </label>
          </div>
        </section>
      {{/if}}

      <section class="field navigate-to-first-post-after-read">
        <label class="checkbox-label">
          <Input
            @type="checkbox"
            @checked={{this.category.navigate_to_first_post_after_read}}
          />
          {{i18n "category.navigate_to_first_post_after_read"}}
        </label>
      </section>

      <section class="field all-topics-wiki">
        <label class="checkbox-label">
          <Input @type="checkbox" @checked={{this.category.all_topics_wiki}} />
          {{i18n "category.all_topics_wiki"}}
        </label>
      </section>

      <section class="field allow-unlimited-owner-edits-on-first-post">
        <label class="checkbox-label">
          <Input
            @type="checkbox"
            @checked={{this.category.allow_unlimited_owner_edits_on_first_post}}
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
            @value={{this.category.moderating_group_ids}}
            @onChange={{this.onCategoryModeratingGroupsChange}}
          />
        </section>
      {{/if}}

      <section class="field require-topic-approval">
        <label class="checkbox-label">
          <Input
            @type="checkbox"
            @checked={{this.category.category_setting.require_topic_approval}}
          />
          {{i18n "category.require_topic_approval"}}
        </label>
      </section>

      <section class="field require-reply-approval">
        <label class="checkbox-label">
          <Input
            @type="checkbox"
            @checked={{this.category.category_setting.require_reply_approval}}
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
              @durationMinutes={{this.category.defaultSlowModeMinutes}}
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
              @durationHours={{this.category.auto_close_hours}}
              @hiddenIntervals={{this.hiddenRelativeIntervals}}
              @onChange={{this.onAutoCloseDurationChange}}
            />
          </div>
          <label class="checkbox-label">
            <Input
              @type="checkbox"
              @checked={{this.category.auto_close_based_on_last_post}}
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
          {{on
            "input"
            (withEventValue
              (fn (mut this.category.category_setting.num_auto_bump_daily))
            )
          }}
          value={{this.category.category_setting.num_auto_bump_daily}}
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
          {{on
            "input"
            (withEventValue
              (fn (mut this.category.category_setting.auto_bump_cooldown_days))
            )
          }}
          value={{this.category.category_setting.auto_bump_cooldown_days}}
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
            @value={{this.category.default_view}}
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
            @value={{this.category.default_top_period}}
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
            @value={{this.category.sort_order}}
            @options={{hash none="category.sort_options.default"}}
            @onChange={{fn (mut this.category.sort_order)}}
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
              @onChange={{fn (mut this.category.sort_ascending)}}
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
            @value={{this.category.default_list_filter}}
          />
        </div>
      </section>

      {{#if this.isParentCategory}}
        <section class="field show-subcategory-list-field">
          <label class="checkbox-label">
            <Input
              @type="checkbox"
              @checked={{this.category.show_subcategory_list}}
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
            @value={{this.category.subcategory_list_style}}
            @options={{hash placementStrategy="absolute"}}
          />
        </section>
      {{/if}}

      <section class="field category-read-only-banner">
        <label for="read-only-message">{{i18n
            "category.read_only_banner"
          }}</label>
        <TextField
          @valueProperty="value"
          @id="read-only-message"
          @value={{this.category.read_only_banner}}
          @options={{hash placementStrategy="absolute"}}
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
          <TextField
            @id="category-email-in"
            @value={{this.category.email_in}}
            class="email-in"
          />

        </section>

        <section class="field email-in-allow-strangers">
          <label class="checkbox-label">
            <Input
              @type="checkbox"
              @checked={{this.category.email_in_allow_strangers}}
            />
            {{i18n "category.email_in_allow_strangers"}}
          </label>
        </section>

        <section class="field mailinglist-mirror">
          <label class="checkbox-label">
            <Input
              @type="checkbox"
              @checked={{this.category.mailinglist_mirror}}
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
  </template>
}
