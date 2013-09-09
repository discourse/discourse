Discourse.initializer({
  name: 'currentUser',

  initialize: function(container) {
    container.register('user:current', Discourse.User.current(), { instantiate: false });
  }
});

Discourse.initializer({
  name: 'injectCurrentUser',

  initialize: function(container) {
    if (container.lookup('user:current')) {
      container.injection('controller', 'currentUser', 'user:current');
      container.injection('route', 'currentUser', 'user:current');
    }
  }
});

Discourse.initializer({
  name: 'trackingState',

  initialize: function(container) {
    container.register('tracking_state:current', Discourse.TopicTrackingState.current(), { instantiate: false });
  }
});

Discourse.initializer({
  name: 'injectTrackingState',

  initialize: function(container) {
    if (container.lookup('tracking_state:current')) {
      container.injection('controller', 'trackingState', 'tracking_state:current');
      container.injection('route', 'trackingState', 'tracking_state:current');
    }
  }
});

Discourse.initializer({
  name: 'screenTrack',

  initialize: function(container) {
    container.register('screen_track:current', Discourse.ScreenTrack.current(), { instantiate: false });
  }
});

Discourse.initializer({
  name: 'injectScreenTrack',

  initialize: function(container) {
    if (container.lookup('screen_track:current')) {
      container.injection('controller', 'screenTrack', 'screen_track:current');
      container.injection('route', 'screenTrack', 'screen_track:current');
    }
  }
});

Discourse.initializer({
  name: 'site',

  initialize: function(container) {
    container.register('site:current', Discourse.Site.current(), { instantiate: false });
  }
});

Discourse.initializer({
  name: 'injectSite',

  initialize: function(container) {
    if (container.lookup('site:current')) {
      container.injection('controller', 'site', 'site:current');
      container.injection('route', 'site', 'site:current');
    }
  }
});

Discourse.initializer({
  name: 'session',

  initialize: function(container) {
    container.register('session:current', Discourse.Session.current(), { instantiate: false });
  }
});

Discourse.initializer({
  name: 'injectSession',

  initialize: function(container) {
    if (container.lookup('session:current')) {
      container.injection('controller', 'session', 'session:current');
      container.injection('route', 'session', 'session:current');
    }
  }
});
