(function() {

  /**
    Basic route for admin flags

    @class AdminFlagsRoute    
    @extends Discourse.Route
    @namespace Discourse
    @module Discourse
  **/
  Discourse.AdminFlagsRoute = Discourse.Route.extend({
    renderTemplate: function() {
      this.render('admin/templates/flags');
    }
  });

}).call(this);
