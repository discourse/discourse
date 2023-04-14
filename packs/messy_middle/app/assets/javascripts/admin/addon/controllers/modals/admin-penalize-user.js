import { inject as service } from "@ember/service";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { isEmpty } from "@ember/utils";
import discourseComputed from "discourse-common/utils/decorators";
import { extractError } from "discourse/lib/ajax-error";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import I18n from "I18n";

export default class AdminPenalizeUserController extends Controller.extend(
  ModalFunctionality
) {
  @service dialog;

  loadingUser = false;
  errorMessage = null;
  penaltyType = null;
  penalizeUntil = null;
  reason = null;
  message = null;
  postId = null;
  postAction = null;
  postEdit = null;
  user = null;
  otherUserIds = null;
  loading = false;
  confirmClose = false;

  onShow() {
    this.setProperties({
      loadingUser: true,
      errorMessage: null,
      penaltyType: null,
      penalizeUntil: null,
      reason: null,
      message: null,
      postId: null,
      postAction: "delete",
      postEdit: null,
      user: null,
      otherUserIds: [],
      loading: false,
      errorMessage: null,
      reason: null,
      message: null,
      confirmClose: false,
    });
  }

  finishedSetup() {
    this.set("penalizeUntil", this.user?.next_penalty);
  }

  beforeClose() {
    if (this.confirmClose) {
      return true;
    }

    if (
      (this.reason && this.reason.length > 1) ||
      (this.message && this.message.length > 1)
    ) {
      this.send("hideModal");
      this.dialog.confirm({
        message: I18n.t("admin.user.confirm_cancel_penalty"),
        didConfirm: () => {
          next(() => {
            this.set("confirmClose", true);
            this.send("closeModal");
          });
        },
        didCancel: () => this.send("reopenModal"),
      });

      return false;
    }
  }

  @discourseComputed("penaltyType")
  modalTitle(penaltyType) {
    if (penaltyType === "suspend") {
      return "admin.user.suspend_modal_title";
    } else if (penaltyType === "silence") {
      return "admin.user.silence_modal_title";
    }
  }

  @discourseComputed("penaltyType")
  buttonLabel(penaltyType) {
    if (penaltyType === "suspend") {
      return "admin.user.suspend";
    } else if (penaltyType === "silence") {
      return "admin.user.silence";
    }
  }

  @discourseComputed(
    "user.penalty_counts.suspended",
    "user.penalty_counts.silenced"
  )
  penaltyHistory(suspendedCount, silencedCount) {
    return I18n.messageFormat("admin.user.penalty_history_MF", {
      SUSPENDED: suspendedCount,
      SILENCED: silencedCount,
    });
  }

  @discourseComputed("penaltyType", "user.canSuspend", "user.canSilence")
  canPenalize(penaltyType, canSuspend, canSilence) {
    if (penaltyType === "suspend") {
      return canSuspend;
    } else if (penaltyType === "silence") {
      return canSilence;
    }

    return false;
  }

  @discourseComputed("penalizing", "penalizeUntil", "reason")
  submitDisabled(penalizing, penalizeUntil, reason) {
    return penalizing || isEmpty(penalizeUntil) || !reason || reason.length < 1;
  }

  @action
  async penalizeUser() {
    if (this.submitDisabled) {
      return;
    }

    this.set("penalizing", true);
    this.set("confirmClose", true);

    if (this.before) {
      this.before();
    }

    let result;
    try {
      const opts = {
        reason: this.reason,
        message: this.message,
        post_id: this.postId,
        post_action: this.postAction,
        post_edit: this.postEdit,
        other_user_ids: this.otherUserIds,
      };

      if (this.penaltyType === "suspend") {
        opts.suspend_until = this.penalizeUntil;
        result = await this.user.suspend(opts);
      } else if (this.penaltyType === "silence") {
        opts.silenced_till = this.penalizeUntil;
        result = await this.user.silence(opts);
      } else {
        // eslint-disable-next-line no-console
        console.error("Unknown penalty type:", this.penaltyType);
      }

      this.send("closeModal");
      if (this.successCallback) {
        await this.successCallback(result);
      }
    } catch {
      this.set("errorMessage", extractError(result));
    } finally {
      this.set("penalizing", false);
    }
  }
}
