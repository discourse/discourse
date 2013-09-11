/**
  A base controller for Discourse that includes Presence support.

  @class Controller
  @extends Ember.Controller
  @namespace Discourse
  @uses Discourse.Presence
  @module Discourse
**/
Discourse.Controller = Ember.Controller.extend(Discourse.Presence, Discourse.HasCurrentUser);
