/**
  A data model representing current session data. You can put transient
  data here you might want later. It is not stored or serialized anywhere.

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

Discourse.Session.reopenClass(Discourse.Singleton);
