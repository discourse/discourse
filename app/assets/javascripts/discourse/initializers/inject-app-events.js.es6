export default {
  name: "inject-app-events",
  initialize: function(container, application) {
    var appEvents = Ember.Object.createWithMixins(Ember.Evented);
    application.register('app-events:main', appEvents, { instantiate: false });

    application.inject('controller', 'appEvents', 'app-events:main');
    application.inject('component', 'appEvents', 'app-events:main');
    application.inject('route', 'appEvents', 'app-events:main');
    application.inject('view', 'appEvents', 'app-events:main');
    application.inject('model', 'appEvents', 'app-events:main');

    Discourse.URL.appEvents = appEvents;
  }
};
