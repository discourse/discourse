
export const TARGET_NAME = (Ember.VERSION[0] === "2") ? 'actions' : '_actions';

export default Ember.Mixin.create({

  delegateAll(actionNames) {
    actionNames = actionNames || [];

    this[TARGET_NAME] = this[TARGET_NAME] || {};

    actionNames.forEach(m => {
      this[TARGET_NAME][m] = function() { this.sendAction(m); };
      this.set(m, m);
    });
  }
});
