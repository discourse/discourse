import { action } from "@ember/object";
import Controller from "@ember/controller";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Controller.extend({
  saving: null,

  @action
  save() {
    this.set("saving", true);

    this.model
      .create()
      .then(() => {
        this.transitionToRoute("group.members", this.model.name);
      })
      .catch(popupAjaxError)
      .finally(() => this.set("saving", false));
  }
});
