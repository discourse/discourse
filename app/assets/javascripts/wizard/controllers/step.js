import getUrl from "discourse-common/lib/get-url";
import Controller from "@ember/controller";

export default Controller.extend({
  wizard: null,
  step: null,

  actions: {
    goNext(response) {
      const next = this.get("step.next");
      if (response && response.refresh_required) {
        if (this.get("step.id") === "locale") {
          document.location = getUrl(`/wizard/steps/${next}`);
          return;
        } else {
          this.send("refresh");
        }
      }
      if (response && response.success) {
        this.transitionToRoute("step", next);
      }
    },
    goBack() {
      this.transitionToRoute("step", this.get("step.previous"));
    },
  },
});
