/**
  This mixin provides a `currentUser` property that can be used to retrieve information
  about the currently logged in user. It is mostly useful to controllers so it can be
  exposted to templates.
**/
Discourse.HasCurrentUser = Em.Mixin.create({

  currentUser: function() {
    return Discourse.User.current();
  }.property().volatile()

});
