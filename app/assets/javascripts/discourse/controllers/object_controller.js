/**
  A custom object controller for Discourse

  @class ObjectController
  @extends Ember.ObjectController
  @namespace Discourse
  @uses Discourse.Presence
  @module Discourse
**/
Discourse.ObjectController = Ember.ObjectController.extend(Discourse.Presence, Discourse.HasCurrentUser);


