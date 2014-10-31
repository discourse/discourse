export default Ember.ArrayController.extend(Discourse.Presence, {
  loading: false,

  show: function() {
    var self = this;
    this.set('loading', true);
    Discourse.ScreenedUrl.findAll().then(function(result) {
      self.set('model', result);
      self.set('loading', false);
    });
  }
});
