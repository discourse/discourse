import Controller from "@ember/controller";
import { action, computed } from "@ember/object";
import { and } from "@ember/object/computed";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { makeArray } from "discourse-common/lib/helpers";
import discourseComputed from "discourse-common/utils/decorators";

export default Controller.extend({
  allowPmUsersEnabled: and(
    "model.user_option.enable_allowed_pm_users",
    "model.user_option.allow_private_messages"
  ),

  mutedUsernames: computed("model.muted_usernames", {
    get() {
      let usernames = this.model.muted_usernames;

      if (typeof usernames === "string") {
        usernames = usernames.split(",").filter(Boolean);
      }

      return makeArray(usernames).uniq();
    },
  }),

  allowedPmUsernames: computed("model.allowed_pm_usernames", {
    get() {
      let usernames = this.model.allowed_pm_usernames;

      if (typeof usernames === "string") {
        usernames = usernames.split(",").filter(Boolean);
      }

      return makeArray(usernames).uniq();
    },
  }),

  init() {
    this._super(...arguments);

    this.saveAttrNames = [
      "allow_private_messages",
      "muted_usernames",
      "allowed_pm_usernames",
      "enable_allowed_pm_users",
    ];
  },

  @action
  onChangeMutedUsernames(usernames) {
    this.model.set("muted_usernames", usernames.uniq().join(","));
  },

  @action
  onChangeAllowedPmUsernames(usernames) {
    this.model.set("allowed_pm_usernames", usernames.uniq().join(","));
  },

  @discourseComputed("model.user_option.allow_private_messages")
  disableAllowPmUsersSetting(allowPrivateMessages) {
    return !allowPrivateMessages;
  },

  @action
  save() {
    this.set("saved", false);

    return this.model
      .save(this.saveAttrNames)
      .then(() => this.set("saved", true))
      .catch(popupAjaxError);
  },
});
