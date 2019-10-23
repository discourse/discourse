import Controller from "@ember/controller";
import computed from "ember-addons/ember-computed-decorators";

export default Controller.extend({
  currentStepId: null,

  @computed("currentStepId")
  showCanvas(currentStepId) {
    return currentStepId === "finished";
  }
});
