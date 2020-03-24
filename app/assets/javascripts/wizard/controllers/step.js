import Controller from "@ember/controller";
export default Controller.extend({
  wizard: null,
  step: null,

  actions: {
    goNext(response) {
      const next = this.get("step.next");
      if (response.refresh_required) {
        this.send("refresh");
      }
      this.transitionToRoute("step", next);
    },
    goBack() {
      this.transitionToRoute("step", this.get("step.previous"));
    }
  }
});
