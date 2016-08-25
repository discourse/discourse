export default Ember.Controller.extend({
  wizard: null,
  step: null,

  actions: {
    goNext() {
      this.transitionToRoute('step', this.get('step.next'));
    },
    goBack() {
      this.transitionToRoute('step', this.get('step.previous'));
    },
  }
});
