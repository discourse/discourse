import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  classNames: ["controls"],

  buttonDisabled: Ember.computed.or("model.isSaving", "saveDisabled"),

  @computed("model.isSaving")
  savingText(saving) {
    return saving ? "saving" : "save";
  },

  actions: {
    saveChanges() {
      this.sendAction();
    }
  }
});
