export default Ember.ObjectController.extend({
  saving: false,
  saved: false,

  saveDisabled: function() {
    if (this.get('saving')) { return true; }
    if ((!this.get('content.allow_blank')) && Ember.empty(this.get('content.content'))) { return true; }
    return false;
  }.property('saving', 'content.content'),

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
