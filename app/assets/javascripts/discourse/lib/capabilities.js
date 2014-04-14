/**
  Singleton to store the application's capabilities

  @class Capabilities
  @namespace Discourse
  @module Discourse
**/
Discourse.Capabilities = Ember.Object.extend({

  /**
    How much slack we should allow with infinite scrolling.

    @property slackRatio
  **/
  slackRatio: function() {
    // Android is slow, so we use a really small slack
    if (this.get('android')) { return 0.5; }

    // Touch devices get more slack due to inertia
    if (this.get('touch')) { return 1.5; }

    // Higher resolution devices (likely laptops/desktops) should get more slack because they
    // can handle the perf.
    return this.get('highRes') ? 2.0 : 0.75;

  }.property('android', 'touch', 'highRes')

});

Discourse.Capabilities.reopenClass(Discourse.Singleton);