import Controller from "@ember/controller";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Controller.extend({
  saving: null,

  actions: {
    save() {
      this.set("saving", true);
      const group = this.model;

      bootbox.alert(group.automatic_membership_email_domains);
      return;

      group
        .create()
        .then(() => {
          this.transitionToRoute("group.members", group.name);
        })
        .catch(popupAjaxError)
        .finally(() => this.set("saving", false));
    },
  },
});
