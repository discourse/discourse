import PreferencesTabController from "discourse/mixins/preferences-tab-controller";
import { popupAjaxError } from "discourse/lib/ajax-error";
import showModal from "discourse/lib/show-modal";
import User from "discourse/models/user";

export default Ember.Controller.extend(PreferencesTabController, {
  saveAttrNames: ["muted_usernames", "ignored_usernames"],
  ignoredUsernames: Ember.computed.alias("model.ignored_usernames"),
  userIsMemberOrAbove: Ember.computed.gte("model.trust_level", 2),
  userIsStaff: Ember.computed.bool("model.staff"),
  ignoredEnabled: Ember.computed.or(
    "userIsMemberOrAbove",
    "userIsStaff"
  ),
  actions: {
    ignoredUsernamesChanged(previous, current) {
      if (current.length > previous.length) {
        const username = current.pop();
        if (username) {
          User.findByUsername(username).then(user => {
            if (user.get("ignored")) {
              return;
            }
            const controller = showModal("ignore-duration", {
              model: user
            });
            controller.setProperties({
              onClose: () => {
                if (!user.get("ignored")) {
                  const usernames = this.get("ignoredUsernames")
                    .split(",")
                    .removeAt(
                      this.get("ignoredUsernames").split(",").length - 1
                    )
                    .join(",");
                  this.set("ignoredUsernames", usernames);
                }
              }
            });
          });
        }
      } else {
        return this.get("model")
          .save(["ignored_usernames"])
          .catch(popupAjaxError);
      }
    },
    save() {
      this.set("saved", false);
      return this.get("model")
        .save(this.get("saveAttrNames"))
        .then(() => this.set("saved", true))
        .catch(popupAjaxError);
    }
  }
});
