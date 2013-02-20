(function() {

  Discourse.HeaderController = Ember.Controller.extend(Discourse.Presence, {
    topic: null,
    showExtraInfo: false,
    toggleStar: function() {
      var _ref;
      if (_ref = this.get('topic')) {
        _ref.toggleStar();
      }
      return false;
    }
  });

}).call(this);
