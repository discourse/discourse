/**
  Return the url to a user's admin page given the username.
  For example:

    <a href="{{unbound adminUserPath username}}">{{unbound username}}</a>

  @method adminUserPath
  @for Handlebars
**/
Handlebars.registerHelper('adminUserPath', function(username) {
  return Discourse.getURL("/admin/users/") + Ember.Handlebars.get(this, username);
});
