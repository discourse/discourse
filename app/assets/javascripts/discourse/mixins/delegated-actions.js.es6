export default Ember.Mixin.create({
  delegateAll(actionNames) {
    actionNames = actionNames || [];

    this.actions = this.actions || {};

    actionNames.forEach(m => {
      this.actions[m] = function() { this.sendAction(m); };
      this.set(m, m);
    });
  }
});
