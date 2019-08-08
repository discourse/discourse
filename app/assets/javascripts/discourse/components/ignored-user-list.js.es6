import { popupAjaxError } from "discourse/lib/ajax-error";
import showModal from "discourse/lib/show-modal";
import User from "discourse/models/user";

export default Ember.Component.extend({
  item: null,
  actions: {
    removeIgnoredUser(item) {
      this.set("saved", false);
      this.items.removeObject(item);
      User.findByUsername(item).then(user => {
        user
          .updateNotificationLevel("normal")
          .catch(popupAjaxError)
          .finally(() => this.set("saved", true));
      });
    },
    newIgnoredUser() {
      const modal = showModal("ignore-duration-with-username", {
        model: this.model
      });
      modal.setProperties({
        ignoredUsername: null,
        onUserIgnored: username => {
          this.items.addObject(username);
        }
      });
    }
  }
});
