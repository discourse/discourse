import ModalFunctionality from "discourse/mixins/modal-functionality";
import ActionSummary from "discourse/models/action-summary";
import { MAX_MESSAGE_LENGTH } from "discourse/models/post-action-type";
import computed from "ember-addons/ember-computed-decorators";
import optionalService from "discourse/lib/optional-service";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Ember.Controller.extend(ModalFunctionality, {
  adminTools: optionalService(),
  userDetails: null,
  selected: null,
  flagTopic: null,
  message: null,
  isWarning: false,
  topicActionByName: null,
  spammerDetails: null,

  onShow() {
    this.setProperties({
      selected: null,
      spammerDetails: null
    });

    let adminTools = this.get("adminTools");
    if (adminTools) {
      adminTools.checkSpammer(this.get("model.user_id")).then(result => {
        this.set("spammerDetails", result);
      });
    }
  },

  @computed("spammerDetails.canDelete", "selected.name_key")
  showDeleteSpammer(canDeleteSpammer, nameKey) {
    return canDeleteSpammer && nameKey === "spam";
  },

  @computed("flagTopic")
  title(flagTopic) {
    return flagTopic ? "flagging_topic.title" : "flagging.title";
  },

  @computed("post", "flagTopic", "model.actions_summary.@each.can_act")
  flagsAvailable() {
    if (!this.get("flagTopic")) {
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
      let lookup = Ember.Object.create();
      let model = this.get("model");
      model.get("actions_summary").forEach(a => {
        a.flagTopic = model;
        a.actionType = this.site.topicFlagTypeById(a.id);
        lookup.set(a.actionType.get("name_key"), ActionSummary.create(a));
      });
      this.set("topicActionByName", lookup);

      return this.site.get("topic_flag_types").filter(item => {
        return _.any(this.get("model.actions_summary"), a => {
          return a.id === item.get("id") && a.can_act;
        });
      });
    }
  },

  @computed("post", "flagTopic", "model.actions_summary.@each.can_act")
  staffFlagsAvailable() {
    return (
      this.get("model.flagsAvailable") &&
      this.get("model.flagsAvailable").length > 1
    );
  },

  @computed("selected.is_custom_flag", "message.length")
  submitEnabled() {
    const selected = this.get("selected");
    if (!selected) return false;

    if (selected.get("is_custom_flag")) {
      const len = this.get("message.length") || 0;
      return (
        len >= Discourse.SiteSettings.min_personal_message_post_length &&
        len <= MAX_MESSAGE_LENGTH
      );
    }
    return true;
  },

  submitDisabled: Ember.computed.not("submitEnabled"),

  // Staff accounts can "take action"
  @computed("flagTopic", "selected.is_custom_flag")
  canTakeAction(flagTopic, isCustomFlag) {
    return !flagTopic && !isCustomFlag && this.currentUser.get("staff");
  },

  @computed("selected.is_custom_flag")
  submitIcon(isCustomFlag) {
    return isCustomFlag ? "envelope" : "flag";
  },

  @computed("selected.is_custom_flag", "flagTopic")
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
      let details = this.get("spammerDetails");
      if (details) {
        details.deleteUser().then(() => window.location.reload());
      }
    },

    takeAction() {
      this.send("createFlag", { takeAction: true });
      this.set("model.hidden", true);
    },

    createFlag(opts) {
      let postAction; // an instance of ActionSummary

      if (!this.get("flagTopic")) {
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
        ? { message: this.get("message") }
        : {};
      if (opts) {
        params = $.extend(params, opts);
      }

      this.send("hideModal");

      postAction
        .act(this.get("model"), params)
        .then(() => {
          this.send("closeModal");
          if (params.message) {
            this.set("message", "");
          }
          this.appEvents.trigger("post-stream:refresh", {
            id: this.get("model.id")
          });
        })
        .catch(error => {
          this.send("closeModal");
          popupAjaxError(error);
        });
    },

    createFlagAsWarning() {
      this.send("createFlag", { isWarning: true });
      this.set("model.hidden", true);
    },

    changePostActionType(action) {
      this.set("selected", action);
    }
  },

  @computed("flagTopic", "selected.name_key")
  canSendWarning(flagTopic, nameKey) {
    return (
      !flagTopic && this.currentUser.get("staff") && nameKey === "notify_user"
    );
  }
});
