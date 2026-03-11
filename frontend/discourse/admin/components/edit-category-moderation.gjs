import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, computed } from "@ember/object";
import { buildCategoryPanel } from "discourse/admin/components/edit-category-panel";
import RelativeTimePicker from "discourse/components/relative-time-picker";
import withEventValue from "discourse/helpers/with-event-value";
import ComboBox from "discourse/select-kit/components/combo-box";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import { i18n } from "discourse-i18n";

const APPROVAL_TYPES = ["none", "all", "except_groups", "only_groups"];

export default class EditCategoryModeration extends buildCategoryPanel(
  "moderation"
) {
  @tracked _topicApprovalType = null;
  @tracked _replyApprovalType = null;

  init() {
    super.init(...arguments);
    this.registerValidator?.(() => this._validateApprovalGroups());
  }

  _validateApprovalGroups() {
    if (
      this.showTopicApprovalGroups &&
      !this.category?.topic_approval_group_ids?.length
    ) {
      return true;
    }
    if (
      this.showReplyApprovalGroups &&
      !this.category?.reply_approval_group_ids?.length
    ) {
      return true;
    }
    return false;
  }

  @computed
  get hiddenRelativeIntervals() {
    return ["mins"];
  }

  @computed
  get approvalTypeOptions() {
    return APPROVAL_TYPES.map((value) => ({
      value,
      name: i18n(`category.approval_types.${value}`),
    }));
  }

  get topicApprovalType() {
    return (
      this._topicApprovalType ??
      this.category?.category_setting?.topic_approval_type ??
      "none"
    );
  }

  get replyApprovalType() {
    return (
      this._replyApprovalType ??
      this.category?.category_setting?.reply_approval_type ??
      "none"
    );
  }

  get showTopicApprovalGroups() {
    const t = this.topicApprovalType;
    return t === "except_groups" || t === "only_groups";
  }

  get showReplyApprovalGroups() {
    const t = this.replyApprovalType;
    return t === "except_groups" || t === "only_groups";
  }

  get topicApprovalGroupsLabel() {
    if (this.topicApprovalType === "except_groups") {
      return i18n("category.approval_groups_except");
    }
    return i18n("category.approval_groups_only");
  }

  get replyApprovalGroupsLabel() {
    if (this.replyApprovalType === "except_groups") {
      return i18n("category.approval_groups_except");
    }
    return i18n("category.approval_groups_only");
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

  @action
  onTopicApprovalTypeChange(value) {
    this._topicApprovalType = value;
    if (this.category?.category_setting) {
      this.set("category.category_setting.topic_approval_type", value);
    }
  }

  @action
  onReplyApprovalTypeChange(value) {
    this._replyApprovalType = value;
    if (this.category?.category_setting) {
      this.set("category.category_setting.reply_approval_type", value);
    }
  }

  @action
  onTopicApprovalGroupsChange(groupIds) {
    this.set("category.topic_approval_group_ids", groupIds);
  }

  @action
  onReplyApprovalGroupsChange(groupIds) {
    this.set("category.reply_approval_group_ids", groupIds);
  }

  <template>
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

      <section class="field topic-approval">
        <h4>{{i18n "category.topic_approval_heading"}}</h4>
        <section class="field topic-approval-type">
          <label>{{i18n "category.topic_approval_type"}}</label>
          <ComboBox
            @valueProperty="value"
            @content={{this.approvalTypeOptions}}
            @value={{this.topicApprovalType}}
            @onChange={{this.onTopicApprovalTypeChange}}
            @options={{hash placementStrategy="absolute"}}
          />
        </section>

        {{#if this.showTopicApprovalGroups}}
          <section class="field topic-approval-groups">
            <label>{{this.topicApprovalGroupsLabel}}</label>
            <GroupChooser
              @content={{this.site.groups}}
              @value={{this.category.topic_approval_group_ids}}
              @onChange={{this.onTopicApprovalGroupsChange}}
            />
            {{#unless this.category.topic_approval_group_ids.length}}
              <p class="form-kit__errors">{{i18n
                  "category.approval_groups_required"
                }}</p>
            {{/unless}}
          </section>
        {{/if}}
      </section>

      <section class="field reply-approval">
        <h4>{{i18n "category.reply_approval_heading"}}</h4>
        <section class="field reply-approval-type">
          <label>{{i18n "category.reply_approval_type"}}</label>
          <ComboBox
            @valueProperty="value"
            @content={{this.approvalTypeOptions}}
            @value={{this.replyApprovalType}}
            @onChange={{this.onReplyApprovalTypeChange}}
            @options={{hash placementStrategy="absolute"}}
          />
        </section>

        {{#if this.showReplyApprovalGroups}}
          <section class="field reply-approval-groups">
            <label>{{this.replyApprovalGroupsLabel}}</label>
            <GroupChooser
              @content={{this.site.groups}}
              @value={{this.category.reply_approval_group_ids}}
              @onChange={{this.onReplyApprovalGroupsChange}}
            />
            {{#unless this.category.reply_approval_group_ids.length}}
              <p class="form-kit__errors">{{i18n
                  "category.approval_groups_required"
                }}</p>
            {{/unless}}
          </section>
        {{/if}}
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
  </template>
}
