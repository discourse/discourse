import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { isEmpty } from "@ember/utils";
import { inject as service } from "@ember/service";
import { extractError } from "discourse/lib/ajax-error";
import I18n from "I18n";

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
      this.args.closeModal();
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
        message: I18n.t("admin.user.confirm_cancel_penalty"),
        didConfirm: () => this.args.closeModal(),
      });
      return false;
    }

    this.args.closeModal();
  }
}
