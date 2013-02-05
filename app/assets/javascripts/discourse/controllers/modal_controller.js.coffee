Discourse.ModalController = Ember.Controller.extend Discourse.Presence,

  show: (view) -> @set('currentView', view)
