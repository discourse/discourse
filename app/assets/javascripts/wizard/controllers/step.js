import getUrl from "discourse-common/lib/get-url";
import Controller from "@ember/controller";
import { action } from "@ember/object";

export default Controller.extend({
  wizard: null,
  step: null,

  @action
  goNext(response) {
    const next = this.get("step.next");
    if (response && response.refresh_required) {
      if (this.get("step.id") === "locale") {
        document.location = getUrl(`/wizard/steps/${next}`);
        return;
      } else {
        this.send("refreshRoute");
      }
    }
    if (response && response.success) {
      this.transitionToRoute("step", next);
    }
  },

  @action
  goBack() {
    this.transitionToRoute("step", this.get("step.previous"));
  },
});
