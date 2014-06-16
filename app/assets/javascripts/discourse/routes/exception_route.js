/**
  Client-side pseudo-route for showing an error page.

  @class ExceptionRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.ExceptionRoute = Discourse.Route.extend({
  serialize: function() {
    return "";
  }
});
