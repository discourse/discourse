export default Ember.Controller.extend({
  saving: false,
  newBio: null,

  saveButtonText: function() {
    return this.get('saving') ? I18n.t("saving") : I18n.t('user.change');
  }.property('saving')

});
