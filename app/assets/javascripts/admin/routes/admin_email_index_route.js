/**
  Handles email routes

  @class AdminEmailRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminEmailIndexRoute = Discourse.Route.extend({

  model: function() {
    return Discourse.EmailSettings.find();
  },

  renderTemplate: function() {
    this.render('admin/templates/email_index', { into: 'adminEmail' });
  }
});
