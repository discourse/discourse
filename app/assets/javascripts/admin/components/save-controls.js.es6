import Component from "@ember/component";
import computed from "ember-addons/ember-computed-decorators";

export default Component.extend({
  classNames: ["controls"],

  buttonDisabled: Ember.computed.or("model.isSaving", "saveDisabled"),

  @computed("model.isSaving")
  savingText(saving) {
    return saving ? "saving" : "save";
  }
});
