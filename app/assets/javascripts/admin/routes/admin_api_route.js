/**
  Handles routes related to api

  @class AdminApiRoute    
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/ 
Discourse.AdminApiRoute = Discourse.Route.extend({
  renderTemplate: function() {    
    this.render({into: 'admin/templates/admin'});
  },

  model: function(params) {
    return Discourse.AdminApi.find();
  }
});
