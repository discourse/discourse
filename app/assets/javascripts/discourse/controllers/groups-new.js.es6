import { popupAjaxError } from "discourse/lib/ajax-error";

export default Ember.Controller.extend({
  saving: null,

  actions: {
    save() {
      this.set("saving", true);
      const group = this.get("model");

      group
        .create()
        .then(() => {
          this.transitionToRoute("group.members", group.name);
        })
        .catch(popupAjaxError)
        .finally(() => this.set("saving", false));
    }
  }
});
