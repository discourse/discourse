import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import RelativeTimePicker from "discourse/components/relative-time-picker";
import concatClass from "discourse/helpers/concat-class";
import withEventValue from "discourse/helpers/with-event-value";
import { POSTING_REVIEW_GROUP_BASED_MODES } from "discourse/lib/constants";
import ComboBox from "discourse/select-kit/components/combo-box";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class UpsertCategoryModeration extends Component {
  @service site;
  @service siteSettings;

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

  get numAutoBumpDaily() {
    return this.categorySetting?.num_auto_bump_daily;
  }

  get autoBumpCooldownDays() {
    return this.categorySetting?.auto_bump_cooldown_days;
  }

  get postingReviewModeOptions() {
    return [
      { name: i18n("category.posting_review_modes.no_one"), value: "no_one" },
      {
        name: i18n("category.posting_review_modes.everyone"),
        value: "everyone",
      },
      {
        name: i18n("category.posting_review_modes.everyone_except"),
        value: "everyone_except",
      },
      {
        name: i18n("category.posting_review_modes.no_one_except"),
        value: "no_one_except",
      },
    ];
  }

  get topicModeRequiresGroups() {
    return POSTING_REVIEW_GROUP_BASED_MODES.includes(
      this.categorySetting?.topic_posting_review_mode
    );
  }

  get replyModeRequiresGroups() {
    return POSTING_REVIEW_GROUP_BASED_MODES.includes(
      this.categorySetting?.reply_posting_review_mode
    );
  }

  get topicGroupChooserTitle() {
    return this.categorySetting?.topic_posting_review_mode === "no_one_except"
      ? i18n("category.posting_review_groups_require_approval")
      : i18n("category.posting_review_groups_no_approval");
  }

  get replyGroupChooserTitle() {
    return this.categorySetting?.reply_posting_review_mode === "no_one_except"
      ? i18n("category.posting_review_groups_require_approval")
      : i18n("category.posting_review_groups_no_approval");
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
      ...(this.categorySetting || {}),
      [key]: value,
    });
  }

  @action
  onCategoryModeratingGroupsChange(groupIds) {
    this.args.form.set("moderating_group_ids", groupIds);
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
  onTopicPostingReviewModeChange(value) {
    this.#updateCategorySetting("topic_posting_review_mode", value);
    if (!POSTING_REVIEW_GROUP_BASED_MODES.includes(value)) {
      this.args.form.set("topic_posting_review_group_ids", []);
    }
  }

  @action
  onReplyPostingReviewModeChange(value) {
    this.#updateCategorySetting("reply_posting_review_mode", value);
    if (!POSTING_REVIEW_GROUP_BASED_MODES.includes(value)) {
      this.args.form.set("reply_posting_review_group_ids", []);
    }
  }

  @action
  validatePostingReviewGroups(name, value, { addError }) {
    if (!value?.length) {
      const type = name.startsWith("topic") ? "topic" : "reply";
      addError(name, {
        title: i18n(`category.require_${type}_approval_for`),
        message: i18n("category.validations.groups_required"),
      });
    }
  }

  <template>
    <@form.Section
      class={{concatClass
        "edit-category-tab"
        "edit-category-tab-moderation"
        "--full"
        (if (eq @selectedTab "moderation") "active")
      }}
    >
      {{#if this.siteSettings.enable_category_group_moderation}}
        <@form.Container @title={{i18n "category.reviewable_by_group"}}>
          <GroupChooser
            @content={{this.site.groups}}
            @value={{this.moderatingGroupIds}}
            @onChange={{this.onCategoryModeratingGroupsChange}}
          />
        </@form.Container>
      {{/if}}

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
      </@form.Container>

      <@form.Field
        @name="auto_close_based_on_last_post"
        @title={{i18n "topic.auto_close.based_on_last_post"}}
        @type="checkbox"
        @format="full"
        as |field|
      >
        <field.Control />
      </@form.Field>

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

      <@form.Section @title={{i18n "category.new_topic_approval"}}>
        <@form.Object @name="category_setting" as |object|>
          <object.Field
            @name="topic_posting_review_mode"
            @title={{i18n "category.require_topic_approval_for"}}
            @type="custom"
            as |field|
          >
            <field.Control>
              <ComboBox
                @valueProperty="value"
                @content={{this.postingReviewModeOptions}}
                @value={{field.value}}
                @onChange={{this.onTopicPostingReviewModeChange}}
                @options={{hash placementStrategy="absolute"}}
              />
            </field.Control>
          </object.Field>

          {{#if this.topicModeRequiresGroups}}
            <@form.Field
              @name="topic_posting_review_group_ids"
              @title={{this.topicGroupChooserTitle}}
              @type="custom"
              @validate={{this.validatePostingReviewGroups}}
              as |field|
            >
              <field.Control>
                <GroupChooser
                  class="posting-review-group-chooser"
                  @content={{this.site.groups}}
                  @value={{field.value}}
                  @onChange={{field.set}}
                  @options={{hash
                    none="category.posting_review_groups_placeholder"
                  }}
                />
              </field.Control>
            </@form.Field>
          {{/if}}
        </@form.Object>
      </@form.Section>

      <@form.Section @title={{i18n "category.new_reply_approval"}}>
        <@form.Object @name="category_setting" as |object|>
          <object.Field
            @name="reply_posting_review_mode"
            @title={{i18n "category.require_reply_approval_for"}}
            @type="custom"
            as |field|
          >
            <field.Control>
              <ComboBox
                @valueProperty="value"
                @content={{this.postingReviewModeOptions}}
                @value={{field.value}}
                @onChange={{this.onReplyPostingReviewModeChange}}
                @options={{hash placementStrategy="absolute"}}
              />
            </field.Control>
          </object.Field>

          {{#if this.replyModeRequiresGroups}}
            <@form.Field
              @name="reply_posting_review_group_ids"
              @title={{this.replyGroupChooserTitle}}
              @type="custom"
              @validate={{this.validatePostingReviewGroups}}
              as |field|
            >
              <field.Control>
                <GroupChooser
                  class="posting-review-group-chooser"
                  @content={{this.site.groups}}
                  @value={{field.value}}
                  @onChange={{field.set}}
                  @options={{hash
                    none="category.posting_review_groups_placeholder"
                  }}
                />
              </field.Control>
            </@form.Field>
          {{/if}}
        </@form.Object>
      </@form.Section>
    </@form.Section>
  </template>
}
