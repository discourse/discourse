/**
  This mixin provides a `currentUser` property that can be used to retrieve information
  about the currently logged in user. It is mostly useful to controllers so it can be
  exposted to templates.

  Outside of templates, code should probably use `Discourse.User.current()` instead of
  this property.

  @class Discourse.HasCurrentUser
  @extends Ember.Mixin
  @namespace Discourse
  @module HasCurrentUser
**/
Discourse.HasCurrentUser = Em.Mixin.create({

  /**
    Returns a reference to the currently logged in user.

    @method currentUser
    @return {Discourse.User} the currently logged in user if present.
  */
  currentUser: function() {
    return Discourse.User.current();
  }.property().volatile()

});





