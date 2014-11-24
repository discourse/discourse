export default Ember.ArrayController.extend(Discourse.Presence, {
  loading: false,
  itemController: 'admin-log-screened-ip-address',

  show: function() {
    var self = this;
    this.set('loading', true);
    Discourse.ScreenedIpAddress.findAll().then(function(result) {
      self.set('model', result);
      self.set('loading', false);
    });
  },

  actions: {
    recordAdded: function(arg) {
      this.get("model").unshiftObject(arg);
    },

    rollUp: function() {
      var self = this;
      this.set("loading", true)
      return Discourse.ScreenedIpAddress.rollUp().then(function() {
        self.send("show");
      });
    }
  }
});
