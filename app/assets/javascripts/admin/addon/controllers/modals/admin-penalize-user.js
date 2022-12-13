import Controller from "@ember/controller";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { inject as service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import discourseComputed from "discourse-common/utils/decorators";
import { extractError } from "discourse/lib/ajax-error";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import I18n from "I18n";
import { Promise } from "rsvp";

export default Controller.extend(ModalFunctionality, {
  dialog: service(),

  errorMessage: null,
  reason: null,
  message: null,
  postEdit: null,
  postAction: null,
  user: null,
  postId: null,
  successCallback: null,
  confirmClose: false,
  penalizeUntil: null,
  penalizing: false,
  otherUserIds: null,

  beforeClose() {
    // prompt a confirmation if we have unsaved content
    if (
      !this.confirmClose &&
      ((this.reason && this.reason.length > 1) ||
        (this.message && this.message.length > 1))
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
  },

  onShow() {
    this.setProperties({
      errorMessage: null,
      reason: null,
      message: null,
      loadingUser: true,
      postId: null,
      postEdit: null,
      postAction: "delete",
      before: null,
      successCallback: null,
      confirmClose: false,
      penalizeUntil: null,
      penalizing: false,
      otherUserIds: [],
    });
  },

  finishedSetup() {
    this.set("penalizeUntil", this.user?.next_penalty);
  },

  @discourseComputed("penaltyType")
  modalTitle(penaltyType) {
    if (penaltyType === "suspend") {
      return "admin.user.suspend_modal_title";
    } else if (penaltyType === "silence") {
      return "admin.user.silence_modal_title";
    }
  },

  @discourseComputed("penaltyType")
  buttonLabel(penaltyType) {
    if (penaltyType === "suspend") {
      return "admin.user.suspend";
    } else if (penaltyType === "silence") {
      return "admin.user.silence";
    }
  },

  @discourseComputed(
    "user.penalty_counts.suspended",
    "user.penalty_counts.silenced"
  )
  penaltyHistory(suspendedCount, silencedCount) {
    return I18n.messageFormat("admin.user.penalty_history_MF", {
      SUSPENDED: suspendedCount,
      SILENCED: silencedCount,
    });
  },

  @discourseComputed("penaltyType", "user.canSuspend", "user.canSilence")
  canPenalize(penaltyType, canSuspend, canSilence) {
    if (penaltyType === "suspend") {
      return canSuspend;
    } else if (penaltyType === "silence") {
      return canSilence;
    }

    return false;
  },

  @discourseComputed("penalizing", "penalizeUntil", "reason")
  submitDisabled(penalizing, penalizeUntil, reason) {
    return penalizing || isEmpty(penalizeUntil) || !reason || reason.length < 1;
  },

  @action
  penalizeUser() {
    if (this.submitDisabled) {
      return;
    }

    this.set("penalizing", true);

    const promise = this.before ? this.before() : Promise.resolve();
    return promise
      .then(() => {
        const opts = {
          reason: this.reason,
          message: this.message,
          post_id: this.postId,
          post_action: this.postAction,
          post_edit: this.postEdit,
          other_user_ids: this.otherUserIds,
        };

        if (this.penaltyType === "suspend") {
          opts.suspend_until = this.suspendUntil;
          return this.user.suspend(opts);
        } else if (this.penaltyType === "silence") {
          opts.silenced_till = this.silenceUntil;
          return this.user.silence(opts);
        }

        // eslint-disable-next-line no-console
        console.error("Unknown penalty type:", this.penaltyType);
      })
      .then((result) => {
        this.set("confirmClose", true);
        this.send("closeModal");
        if (this.successCallback) {
          this.successCallback(result);
        }
      })
      .catch((error) => {
        this.set("errorMessage", extractError(error));
      })
      .finally(() => {
        this.set("penalizing", false);
      });
  },
});
