/**
  Handles routes related to pages

  @class AdminPagesRoute    
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/ 
Discourse.AdminPagesRoute = Discourse.Route.extend({
  model: function() {
    return Discourse.Page.findAll();
  },

  renderTemplate: function() {    
    this.render({into: 'admin/templates/admin'});
  }
});
