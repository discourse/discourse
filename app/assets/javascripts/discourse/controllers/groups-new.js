import { action } from "@ember/object";
import Controller from "@ember/controller";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { popupAutomaticMembershipAlert } from "discourse/lib/utilities";

export default Controller.extend({
  saving: null,

  @action
  save() {
    this.set("saving", true);
    const group = this.model;

    popupAutomaticMembershipAlert(
      group.id,
      group.automatic_membership_email_domains
    );

    group
      .create()
      .then(() => {
        this.transitionToRoute("group.members", group.name);
      })
      .catch(popupAjaxError)
      .finally(() => this.set("saving", false));
  }
});
