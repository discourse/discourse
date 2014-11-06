export default Ember.ObjectController.extend({
  saving: false,
  saved: false,

  saveDisabled: function() {
    if (this.get('saving')) { return true; }
    if ((!this.get('allow_blank')) && Ember.empty(this.get('value'))) { return true; }
    return false;
  }.property('saving', 'value'),

  actions: {
    saveChanges: function() {
      var self = this;
      self.setProperties({saving: true, saved: false});
      self.get('model').save().then(function () {
        self.setProperties({saving: false, saved: true});
      });
    }
  }
});
