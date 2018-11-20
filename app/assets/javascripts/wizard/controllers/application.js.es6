import computed from "ember-addons/ember-computed-decorators";

export default Ember.Controller.extend({
  currentStepId: null,

  @computed("currentStepId")
  showCanvas(currentStepId) {
    return currentStepId === "finished";
  }
});
