import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  classNameBindings: [":wizard-step-form", "customStepClass"],

  @computed("step.id") customStepClass: stepId => `wizard-step-${stepId}`
});
