import { schedule } from "@ember/runloop";
import Controller from "@ember/controller";
import I18n from "I18n";
import { MAX_MESSAGE_LENGTH } from "discourse/models/post-action-type";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { Promise } from "rsvp";
import User from "discourse/models/user";
import discourseComputed, { bind } from "discourse-common/utils/decorators";
import { not } from "@ember/object/computed";
import optionalService from "discourse/lib/optional-service";
import { classify } from "@ember/string";

export default Controller.extend(ModalFunctionality, {
  adminTools: optionalService(),
  userDetails: null,
  selected: null,
  message: null,
  isWarning: false,
  topicActionByName: null,
  spammerDetails: null,
  flagActions: null,
  flagTarget: null,

  init() {
    this._super(...arguments);
    this.flagActions = {
      icon: "gavel",
      label: I18n.t("flagging.take_action"),
      actions: [
        {
          id: "agree_and_keep",
          icon: "thumbs-up",
          label: I18n.t("flagging.take_action_options.default.title"),
          description: I18n.t("flagging.take_action_options.default.details"),
        },
        {
          id: "agree_and_suspend",
          icon: "ban",
          label: I18n.t("flagging.take_action_options.suspend.title"),
          description: I18n.t("flagging.take_action_options.suspend.details"),
          client_action: "suspend",
        },
        {
          id: "agree_and_silence",
          icon: "microphone-slash",
          label: I18n.t("flagging.take_action_options.silence.title"),
          description: I18n.t("flagging.take_action_options.silence.details"),
          client_action: "silence",
        },
      ],
    };
  },

  @bind
  keyDown(event) {
    // CTRL+ENTER or CMD+ENTER
    if (event.key === "Enter" && (event.ctrlKey || event.metaKey)) {
      if (this.submitEnabled) {
        this.send("createFlag");
        return false;
      }
    }
  },

  clientSuspend(performAction) {
    this._penalize("showSuspendModal", performAction);
  },

  clientSilence(performAction) {
    this._penalize("showSilenceModal", performAction);
  },

  _penalize(adminToolMethod, performAction) {
    if (this.adminTools) {
      return User.findByUsername(this.model.username).then((createdBy) => {
        const opts = { before: performAction };

        if (this.flagTarget.editable()) {
          opts.postId = this.model.id;
          opts.postEdit = this.model.cooked;
        }

        return this.adminTools[adminToolMethod](createdBy, opts);
      });
    }
  },

  onShow() {
    this.setProperties({
      selected: null,
      spammerDetails: null,
    });

    if (this.adminTools) {
      this.adminTools.checkSpammer(this.get("model.user_id")).then((result) => {
        this.set("spammerDetails", result);
      });
    }

    schedule("afterRender", () => {
      const element = document.querySelector(".flag-modal");
      element.addEventListener("keydown", this.keyDown);
    });
  },

  onClose() {
    const element = document.querySelector(".flag-modal");
    element.removeEventListener("keydown", this.keyDown);
  },

  @discourseComputed("spammerDetails.canDelete", "selected.name_key")
  showDeleteSpammer(canDeleteSpammer, nameKey) {
    return canDeleteSpammer && nameKey === "spam";
  },

  @discourseComputed("flagTarget")
  title(flagTarget) {
    return flagTarget.title();
  },

  @discourseComputed(
    "post",
    "flagTarget",
    "model.actions_summary.@each.can_act"
  )
  flagsAvailable() {
    return this.flagTarget.flagsAvailable(this, this.site, this.model);
  },

  @discourseComputed(
    "post",
    "flagTarget",
    "model.actions_summary.@each.can_act"
  )
  staffFlagsAvailable() {
    return (
      this.get("model.flagsAvailable") &&
      this.get("model.flagsAvailable").length > 1
    );
  },

  @discourseComputed("selected.is_custom_flag", "message.length")
  submitEnabled() {
    const selected = this.selected;
    if (!selected) {
      return false;
    }

    if (selected.get("is_custom_flag")) {
      const len = this.get("message.length") || 0;
      return (
        len >= this.siteSettings.min_personal_message_post_length &&
        len <= MAX_MESSAGE_LENGTH
      );
    }
    return true;
  },

  submitDisabled: not("submitEnabled"),
  cantFlagForReview: not("notifyModeratorsFlag"),

  @discourseComputed("flagsAvailable")
  notifyModeratorsFlag(flagsAvailable) {
    const notifyModeratorsID = 7;
    return flagsAvailable.find((f) => f.id === notifyModeratorsID);
  },

  // Staff accounts can "take action"
  @discourseComputed("flagTarget", "selected.is_custom_flag")
  canTakeAction(flagTarget, isCustomFlag) {
    return (
      !flagTarget.targetsTopic() &&
      !isCustomFlag &&
      this.currentUser.get("staff")
    );
  },

  @discourseComputed("selected.is_custom_flag")
  submitIcon(isCustomFlag) {
    return isCustomFlag ? "envelope" : "flag";
  },

  @discourseComputed("selected.is_custom_flag", "flagTarget")
  submitLabel(isCustomFlag, flagTarget) {
    if (isCustomFlag) {
      return flagTarget.customSubmitLabel();
    }

    return flagTarget.submitLabel();
  },

  actions: {
    deleteSpammer() {
      let details = this.spammerDetails;
      if (details) {
        details.deleteUser().then(() => window.location.reload());
      }
    },

    takeAction(action) {
      let performAction = (o = {}) => {
        o.takeAction = true;
        this.send("createFlag", o);
        return Promise.resolve();
      };

      if (action.client_action) {
        let actionMethod = this[`client${classify(action.client_action)}`];
        if (actionMethod) {
          return actionMethod.call(this, () =>
            performAction({ skipClose: true })
          );
        } else {
          // eslint-disable-next-line no-console
          console.error(`No handler for ${action.client_action} found`);
          return;
        }
      } else {
        this.set("model.hidden", true);
        return performAction();
      }
    },

    createFlag(opts) {
      const params = opts || {};

      if (this.get("selected.is_custom_flag")) {
        params.message = this.message;
      }

      this.flagTarget.create(this, params);
    },

    createFlagAsWarning() {
      this.send("createFlag", { isWarning: true });
      this.set("model.hidden", true);
    },

    flagForReview() {
      if (!this.selected) {
        this.set("selected", this.get("notifyModeratorsFlag"));
      }

      this.send("createFlag", { queue_for_review: true });
      this.set("model.hidden", true);
    },

    changePostActionType(action) {
      this.set("selected", action);
    },
  },

  @discourseComputed("flagTarget", "selected.name_key")
  canSendWarning(flagTarget, nameKey) {
    return (
      !flagTarget.targetsTopic() &&
      this.currentUser.get("staff") &&
      nameKey === "notify_user"
    );
  },
});
