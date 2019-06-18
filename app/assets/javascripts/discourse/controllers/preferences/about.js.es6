import computed from "ember-addons/ember-computed-decorators";

export default Ember.Controller.extend({
  saving: false,
  newBio: null,

  @computed("saving")
  saveButtonText(saving) {
    return saving ? I18n.t("saving") : I18n.t("user.change");
  }
});
