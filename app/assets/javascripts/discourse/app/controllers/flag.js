import { schedule } from "@ember/runloop";
import ActionSummary from "discourse/models/action-summary";
import Controller from "@ember/controller";
import EmberObject from "@ember/object";
import I18n from "I18n";
import { MAX_MESSAGE_LENGTH } from "discourse/models/post-action-type";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { Promise } from "rsvp";
import User from "discourse/models/user";
import discourseComputed, { bind } from "discourse-common/utils/decorators";
import { not } from "@ember/object/computed";
import optionalService from "discourse/lib/optional-service";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Controller.extend(ModalFunctionality, {
  adminTools: optionalService(),
  userDetails: null,
  selected: null,
  flagTopic: null,
  message: null,
  isWarning: false,
  topicActionByName: null,
  spammerDetails: null,
  flagActions: null,

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
        let postId = this.model.id;
        let postEdit = this.model.cooked;
        return this.adminTools[adminToolMethod](createdBy, {
          postId,
          postEdit,
          before: performAction,
        });
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

  @discourseComputed("flagTopic")
  title(flagTopic) {
    return flagTopic ? "flagging_topic.title" : "flagging.title";
  },

  @discourseComputed("post", "flagTopic", "model.actions_summary.@each.can_act")
  flagsAvailable() {
    if (!this.flagTopic) {
      // flagging post
      let flagsAvailable = this.get("model.flagsAvailable");

      // "message user" option should be at the top
      const notifyUserIndex = flagsAvailable.indexOf(
        flagsAvailable.filterBy("name_key", "notify_user")[0]
      );
      if (notifyUserIndex !== -1) {
        const notifyUser = flagsAvailable[notifyUserIndex];
        flagsAvailable.splice(notifyUserIndex, 1);
        flagsAvailable.splice(0, 0, notifyUser);
      }
      return flagsAvailable;
    } else {
      // flagging topic
      let lookup = EmberObject.create();
      let model = this.model;
      model.get("actions_summary").forEach((a) => {
        a.flagTopic = model;
        a.actionType = this.site.topicFlagTypeById(a.id);
        lookup.set(a.actionType.get("name_key"), ActionSummary.create(a));
      });
      this.set("topicActionByName", lookup);

      return this.site.get("topic_flag_types").filter((item) => {
        return this.get("model.actions_summary").some((a) => {
          return a.id === item.get("id") && a.can_act;
        });
      });
    }
  },

  @discourseComputed("post", "flagTopic", "model.actions_summary.@each.can_act")
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
  @discourseComputed("flagTopic", "selected.is_custom_flag")
  canTakeAction(flagTopic, isCustomFlag) {
    return !flagTopic && !isCustomFlag && this.currentUser.get("staff");
  },

  @discourseComputed("selected.is_custom_flag")
  submitIcon(isCustomFlag) {
    return isCustomFlag ? "envelope" : "flag";
  },

  @discourseComputed("selected.is_custom_flag", "flagTopic")
  submitLabel(isCustomFlag, flagTopic) {
    if (isCustomFlag) {
      return flagTopic
        ? "flagging_topic.notify_action"
        : "flagging.notify_action";
    }
    return flagTopic ? "flagging_topic.action" : "flagging.action";
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
        let actionMethod = this[`client${action.client_action.classify()}`];
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
      let postAction; // an instance of ActionSummary

      if (!this.flagTopic) {
        postAction = this.get("model.actions_summary").findBy(
          "id",
          this.get("selected.id")
        );
      } else {
        postAction = this.get(
          "topicActionByName." + this.get("selected.name_key")
        );
      }

      let params = this.get("selected.is_custom_flag")
        ? { message: this.message }
        : {};

      if (opts) {
        params = Object.assign(params, opts);
      }

      this.appEvents.trigger(
        this.flagTopic ? "topic:flag-created" : "post:flag-created",
        this.model,
        postAction,
        params
      );

      this.send("hideModal");

      postAction
        .act(this.model, params)
        .then(() => {
          if (this.isDestroying || this.isDestroyed) {
            return;
          }

          if (!params.skipClose) {
            this.send("closeModal");
          }
          if (params.message) {
            this.set("message", "");
          }
          this.appEvents.trigger("post-stream:refresh", {
            id: this.get("model.id"),
          });
        })
        .catch((error) => {
          if (!this.isDestroying && !this.isDestroyed) {
            this.send("closeModal");
          }
          popupAjaxError(error);
        });
    },

    createFlagAsWarning() {
      this.send("createFlag", { isWarning: true });
      this.set("model.hidden", true);
    },

    flagForReview() {
      this.set("selected", this.get("notifyModeratorsFlag"));
      this.send("createFlag", { queue_for_review: true });
      this.set("model.hidden", true);
    },

    changePostActionType(action) {
      this.set("selected", action);
    },
  },

  @discourseComputed("flagTopic", "selected.name_key")
  canSendWarning(flagTopic, nameKey) {
    return (
      !flagTopic && this.currentUser.get("staff") && nameKey === "notify_user"
    );
  },
});
