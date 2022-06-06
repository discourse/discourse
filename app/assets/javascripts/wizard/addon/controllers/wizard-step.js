import getUrl from "discourse-common/lib/get-url";
import Controller from "@ember/controller";
import { action } from "@ember/object";

export default Controller.extend({
  wizard: null,
  step: null,

  @action
  goNext(response) {
    const next = this.get("step.next");

    if (response?.refresh_required) {
      if (this.step.id === "locale") {
        document.location = getUrl(`/wizard/steps/${next}`);
      } else {
        this.send("refreshRoute");
      }

      return;
    }

    if (response?.success) {
      this.transitionToRoute("wizard.step", next);
    }
  },

  @action
  goBack() {
    this.transitionToRoute("wizard.step", this.step.previous);
  },
});
