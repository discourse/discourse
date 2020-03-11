import { makeArray } from "discourse-common/lib/helpers";
import { alias, gte, or } from "@ember/object/computed";
import { action, computed } from "@ember/object";
import Controller from "@ember/controller";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Controller.extend({
  ignoredUsernames: alias("model.ignored_usernames"),
  userIsMemberOrAbove: gte("model.trust_level", 2),
  ignoredEnabled: or("userIsMemberOrAbove", "model.staff"),

  mutedUsernames: computed("model.muted_usernames", {
    get() {
      let usernames = this.model.muted_usernames;

      if (typeof usernames === "string") {
        usernames = usernames.split(",").filter(Boolean);
      }

      return makeArray(usernames).uniq();
    }
  }),

  init() {
    this._super(...arguments);

    this.saveAttrNames = ["muted_usernames", "ignored_usernames"];
  },

  @action
  onChangeMutedUsernames(usernames) {
    this.model.set("muted_usernames", usernames.uniq().join(","));
  },

  @action
  save() {
    this.set("saved", false);

    return this.model
      .save(this.saveAttrNames)
      .then(() => this.set("saved", true))
      .catch(popupAjaxError);
  }
});
