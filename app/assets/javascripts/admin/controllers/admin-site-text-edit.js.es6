export default Ember.Controller.extend({
  saved: false,

  saveDisabled: function() {
    if (this.get('model.isSaving')) { return true; }
    if ((!this.get('allow_blank')) && Ember.isEmpty(this.get('model.value'))) { return true; }
    return false;
  }.property('model.iSaving', 'model.value'),

  actions: {
    saveChanges() {
      const model = this.get('model');
      model.save(model.getProperties('value')).then(() => this.set('saved', true));
    }
  }
});
