(function() {

  /**
    The default view in the admin section

    @class AdminDashboardView    
    @extends Discourse.View
    @namespace Discourse
    @module Discourse
  **/ 
  Discourse.AdminDashboardView = window.Discourse.View.extend({
    templateName: 'admin/templates/dashboard'
  });

}).call(this);
