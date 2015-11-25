export default Ember.Controller.extend({
  saved: false,

  saveDisabled: function() {
    return ((!this.get('allow_blank')) && Ember.isEmpty(this.get('model.value')));
  }.property('model.iSaving', 'model.value'),

  actions: {
    saveChanges() {
      const model = this.get('model');
      model.save(model.getProperties('value')).then(() => this.set('saved', true));
    }
  }
});
