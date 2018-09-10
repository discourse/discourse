import getUrl from "discourse-common/lib/get-url";

export default Ember.Controller.extend({
  wizard: null,
  step: null,

  actions: {
    goNext(response) {
      const next = this.get("step.next");
      if (response.refresh_required) {
        document.location = getUrl(`/wizard/steps/${next}`);
      } else {
        this.transitionToRoute("step", next);
      }
    },
    goBack() {
      this.transitionToRoute("step", this.get("step.previous"));
    }
  }
});
