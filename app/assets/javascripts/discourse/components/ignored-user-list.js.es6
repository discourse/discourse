/* You might be looking for navigation-item. */
import computed from "ember-addons/ember-computed-decorators";
import {popupAjaxError} from "discourse/lib/ajax-error";
import showModal from "discourse/lib/show-modal";
import User from "discourse/models/user";

export default Ember.Component.extend({
  item: null,
  actions: {
    removeItem(item) {
      this.set("saved", false);
      this.get("items").removeObject(item);
      User.findByUsername(item).then(user => {
        user
          .updateNotificationLevel("normal")
          .catch(popupAjaxError)
          .finally(() => this.set("saved", true));
      });
    },
    newItem() {
      const controller = showModal("ignore-duration-with-username", {
        model: this.get("model")
      });
      controller.setProperties({
        onSuccess: (username) => {
          this.get("items").addObject(username);
        },
        onClose: () => {
        }
      });
    },
  }
});
