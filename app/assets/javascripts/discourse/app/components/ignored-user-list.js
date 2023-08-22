import Component from "@ember/component";
import { inject as service } from "@ember/service";
import User from "discourse/models/user";
import { popupAjaxError } from "discourse/lib/ajax-error";
import IgnoreDurationModal from "./modal/ignore-duration-with-username";

export default Component.extend({
  modal: service(),
  item: null,
  actions: {
    removeIgnoredUser(item) {
      this.set("saved", false);
      this.items.removeObject(item);
      User.findByUsername(item).then((user) => {
        user
          .updateNotificationLevel({
            level: "normal",
            actingUser: this.model,
          })
          .catch(popupAjaxError)
          .finally(() => this.set("saved", true));
      });
    },
    newIgnoredUser() {
      this.modal.show(IgnoreDurationModal, {
        model: {
          actingUser: this.model,
          ignoredUsername: null,
          onUserIgnored: (username) => {
            this.items.addObject(username);
          },
        },
      });
    },
  },
});
