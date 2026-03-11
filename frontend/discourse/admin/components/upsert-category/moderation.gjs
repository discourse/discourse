import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import RelativeTimePicker from "discourse/components/relative-time-picker";
import concatClass from "discourse/helpers/concat-class";
import withEventValue from "discourse/helpers/with-event-value";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

const APPROVAL_TYPES = ["none", "all", "except_groups", "only_groups"];

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

  get approvalTypeOptions() {
    return APPROVAL_TYPES.map((value) => ({
      value,
      name: i18n(`category.approval_types.${value}`),
    }));
  }

  get topicApprovalType() {
    return this.categorySetting?.topic_approval_type ?? "none";
  }

  get replyApprovalType() {
    return this.categorySetting?.reply_approval_type ?? "none";
  }

  get showTopicApprovalGroups() {
    const type = this.topicApprovalType;
    return type === "except_groups" || type === "only_groups";
  }

  get showReplyApprovalGroups() {
    const type = this.replyApprovalType;
    return type === "except_groups" || type === "only_groups";
  }

  get topicApprovalGroupsLabel() {
    if (this.topicApprovalType === "except_groups") {
      return htmlSafe(i18n("category.approval_groups_except"));
    }
    return i18n("category.approval_groups_only");
  }

  get replyApprovalGroupsLabel() {
    if (this.replyApprovalType === "except_groups") {
      return htmlSafe(i18n("category.approval_groups_except"));
    }
    return i18n("category.approval_groups_only");
  }

  get topicApprovalGroupIds() {
    return this.args.transientData?.topic_approval_group_ids ?? [];
  }

  get replyApprovalGroupIds() {
    return this.args.transientData?.reply_approval_group_ids ?? [];
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
  onTopicApprovalGroupsChange(groupIds) {
    this.args.form.set("topic_approval_group_ids", groupIds);
  }

  @action
  onReplyApprovalGroupsChange(groupIds) {
    this.args.form.set("reply_approval_group_ids", groupIds);
  }

  <template>
    <@form.Section
      class={{concatClass
        "edit-category-tab"
        "edit-category-tab-moderation"
        (if (eq @selectedTab "moderation") "active")
      }}
    >
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

        <@form.Object @name="category_setting" as |object|>
          <object.Field
            @name="topic_approval_type"
            @title={{i18n "category.topic_approval_type"}}
            as |field|
          >
            <field.Select @includeNone={{false}} as |select|>
              {{#each this.approvalTypeOptions as |opt|}}
                <select.Option @value={{opt.value}}>{{opt.name}}</select.Option>
              {{/each}}
            </field.Select>
          </object.Field>
        </@form.Object>

        {{#if this.showTopicApprovalGroups}}
          <div class="topic-approval-groups">
            <label>{{this.topicApprovalGroupsLabel}}</label>
            <GroupChooser
              @content={{this.site.groups}}
              @value={{this.topicApprovalGroupIds}}
              @onChange={{this.onTopicApprovalGroupsChange}}
            />
          </div>
        {{/if}}

        <@form.Object @name="category_setting" as |object|>
          <object.Field
            @name="reply_approval_type"
            @title={{i18n "category.reply_approval_type"}}
            as |field|
          >
            <field.Select @includeNone={{false}} as |select|>
              {{#each this.approvalTypeOptions as |opt|}}
                <select.Option @value={{opt.value}}>{{opt.name}}</select.Option>
              {{/each}}
            </field.Select>
          </object.Field>
        </@form.Object>

        {{#if this.showReplyApprovalGroups}}
          <div class="reply-approval-groups">
            <label>{{this.replyApprovalGroupsLabel}}</label>
            <GroupChooser
              @content={{this.site.groups}}
              @value={{this.replyApprovalGroupIds}}
              @onChange={{this.onReplyApprovalGroupsChange}}
            />
          </div>
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
          as |field|
        >
          <field.Checkbox />
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
      </@form.Section>
    </@form.Section>
  </template>
}
