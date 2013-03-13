  /**
    A base view that gives us common functionality, for example `present` and `blank`

    @class View
    @extends Ember.View
    @uses Discourse.Presence
    @namespace Discourse
    @module Discourse
  **/
  Discourse.View = Ember.View.extend(Discourse.Presence, {});
