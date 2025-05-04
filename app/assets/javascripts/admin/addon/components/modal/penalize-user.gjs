import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import FutureDateInput from "discourse/components/future-date-input";
import htmlSafe from "discourse/helpers/html-safe";
import { extractError } from "discourse/lib/ajax-error";
import I18n, { i18n } from "discourse-i18n";
import AdminPenaltyPostAction from "admin/components/admin-penalty-post-action";
import AdminPenaltyReason from "admin/components/admin-penalty-reason";
import AdminPenaltySimilarUsers from "admin/components/admin-penalty-similar-users";

export default class PenalizeUser extends Component {
  @service dialog;
  @service siteSettings;

  @tracked penalizeUntil = this.args.model.user.next_penalty;
  @tracked confirmClose = false;
  @tracked otherUserIds = [];
  @tracked postAction = "delete";
  @tracked postEdit = this.args.model.postEdit;
  @tracked flash;
  @tracked reason;
  @tracked message;

  constructor() {
    super(...arguments);
    if (this.postEdit && this.siteSettings.penalty_include_post_message) {
      this.message = `-------------------\n${this.postEdit}\n-------------------`;
    }
  }

  get modalTitle() {
    if (this.args.model.penaltyType === "suspend") {
      return "admin.user.suspend_modal_title";
    } else if (this.args.model.penaltyType === "silence") {
      return "admin.user.silence_modal_title";
    }
  }

  get buttonLabel() {
    if (this.args.model.penaltyType === "suspend") {
      return "admin.user.suspend";
    } else if (this.args.model.penaltyType === "silence") {
      return "admin.user.silence";
    }
  }

  get penaltyHistory() {
    return I18n.messageFormat("admin.user.penalty_history_MF", {
      SUSPENDED: this.args.model.user.penalty_counts?.suspended,
      SILENCED: this.args.model.user.penalty_counts?.silenced,
    });
  }

  get canPenalize() {
    if (this.args.model.penaltyType === "suspend") {
      return this.args.model.user.canSuspend;
    } else if (this.args.model.penaltyType === "silence") {
      return this.args.model.user.canSilence;
    }
    return false;
  }

  get submitDisabled() {
    return (
      this.penalizing ||
      isEmpty(this.penalizeUntil) ||
      !this.reason ||
      this.reason.length < 1
    );
  }

  @action
  async penalizeUser() {
    if (this.submitDisabled) {
      return;
    }
    this.penalizing = true;
    this.confirmClose = true;
    if (this.before) {
      this.before();
    }

    let result;
    try {
      const opts = {
        reason: this.reason,
        message: this.message,
        post_id: this.args.model.postId,
        post_action: this.postAction,
        post_edit: this.postEdit,
        other_user_ids: this.otherUserIds,
      };

      if (this.args.model.penaltyType === "suspend") {
        opts.suspend_until = this.penalizeUntil;
        result = await this.args.model.user.suspend(opts);
      } else if (this.args.model.penaltyType === "silence") {
        opts.silenced_till = this.penalizeUntil;
        result = await this.args.model.user.silence(opts);
      } else {
        // eslint-disable-next-line no-console
        console.error("Unknown penalty type:", this.args.model.penaltyType);
      }
      this.args.closeModal({ success: true });
      if (this.successCallback) {
        await this.successCallback(result);
      }
    } catch {
      this.flash = extractError(result);
    } finally {
      this.penalizing = false;
    }
  }

  @action
  warnBeforeClosing() {
    if (!this.confirmClose && (this.reason?.length || this.message?.length)) {
      this.dialog.confirm({
        message: i18n("admin.user.confirm_cancel_penalty"),
        didConfirm: () => this.args.closeModal({ success: false }),
      });
      return false;
    }

    this.args.closeModal({ success: false });
  }

  @action
  similarUsersChanged(userIds) {
    this.otherUserIds = userIds;
  }

  <template>
    <DModal
      class="{{@model.penaltyType}}-user-modal"
      @title={{i18n this.modalTitle}}
      @closeModal={{this.warnBeforeClosing}}
      @flash={{this.flash}}
    >
      <:body>
        {{#if this.canPenalize}}
          <div class="penalty-duration-controls">
            {{#if (eq @model.penaltyType "suspend")}}
              <FutureDateInput
                @label="admin.user.suspend_duration"
                @clearable={{false}}
                @input={{this.penalizeUntil}}
                @onChangeInput={{fn (mut this.penalizeUntil)}}
                class="suspend-until"
              />
            {{else if (eq @model.penaltyType "silence")}}
              <FutureDateInput
                @label="admin.user.silence_duration"
                @clearable={{false}}
                @input={{this.penalizeUntil}}
                @onChangeInput={{fn (mut this.penalizeUntil)}}
                class="silence-until"
              />
            {{/if}}
          </div>
          {{#if (eq @model.penaltyType "suspend")}}
            <div class="penalty-reason-visibility">
              {{#if this.siteSettings.hide_suspension_reasons}}
                {{htmlSafe (i18n "admin.user.suspend_reason_hidden_label")}}
              {{else}}
                {{htmlSafe (i18n "admin.user.suspend_reason_label")}}
              {{/if}}
            </div>
          {{/if}}
          <AdminPenaltyReason
            @penaltyType={{@model.penaltyType}}
            @reason={{this.reason}}
            @message={{this.message}}
          />
          {{#if @model.postId}}
            <AdminPenaltyPostAction
              @postId={{@model.postId}}
              @postAction={{this.postAction}}
              @postEdit={{this.postEdit}}
            />
          {{/if}}
          {{#if @model.user.similar_users_count}}
            <AdminPenaltySimilarUsers
              @penaltyType={{@model.penaltyType}}
              @user={{@model.user}}
              @selectedUserIds={{this.otherUserIds}}
              @onUsersChanged={{this.similarUsersChanged}}
            />
          {{/if}}
        {{else}}
          {{#if (eq @model.penaltyType "suspend")}}
            <div class="cant-suspend">{{i18n "admin.user.cant_suspend"}}</div>
          {{else if (eq @model.penaltyType "silence")}}
            <div class="cant-silence">{{i18n "admin.user.cant_silence"}}</div>
          {{/if}}
        {{/if}}
      </:body>
      <:footer>
        <div class="penalty-history">{{htmlSafe this.penaltyHistory}}</div>
        <DButton
          class="btn-danger perform-penalize"
          @action={{this.penalizeUser}}
          @disabled={{this.submitDisabled}}
          @icon="ban"
          @label={{this.buttonLabel}}
        />
        <DButton
          class="btn-flat d-modal-cancel"
          @action={{this.warnBeforeClosing}}
          @label="cancel"
        />
      </:footer>
    </DModal>
  </template>
}
