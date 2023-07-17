import getUrl from "discourse-common/lib/get-url";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default Controller.extend({
  router: service(),

  wizard: null,
  step: null,

  @action
  goNext(response) {
    const next = this.get("step.next");

    if (response?.refresh_required) {
      document.location = getUrl(`/wizard/steps/${next}`);
    } else if (response?.success && next) {
      this.router.transitionToRoute("wizard.step", next);
    } else if (response?.success) {
      this.router.transitionToRoute("discovery.latest");
    }
  },

  @action
  goBack() {
    this.router.transitionToRoute("wizard.step", this.step.previous);
  },
});
