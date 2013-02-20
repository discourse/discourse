(function() {

  Discourse.ModalController = Ember.Controller.extend(Discourse.Presence, {
    show: function(view) {
      return this.set('currentView', view);
    }
  });

}).call(this);
