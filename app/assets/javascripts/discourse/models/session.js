/**
  A data model representing current session data. You can put transient
  data here you might want later.

  @class Session
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.Session = Discourse.Model.extend({
  init: function() {
    this.set('highestSeenByTopic', {});
  }
});

Discourse.Session.reopenClass({

  /**
    Returns the current session.

    @method current
    @returns {Discourse.Session} the current session singleton
  **/
  current: function(property, value) {
    if (!this.currentSession) {
      this.currentSession = Discourse.Session.create();
    }

    // If we found the current session
    if (typeof property !== "undefined") {
      if (typeof value !== "undefined") {
        this.currentSession.set(property, value);
      } else {
        return this.currentSession.get(property);
      }
    }

    return property ? this.currentSession.get(property) : this.currentSession;
  }
});
