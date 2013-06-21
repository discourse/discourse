/**
  Handles email routes

  @class AdminEmailRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminEmailIndexRoute = Discourse.Route.extend({

  setupController: function(controller) {
    Discourse.EmailSettings.find().then(function (model) {
      controller.set('model', model);
    });
  },

  renderTemplate: function() {
    this.render('admin/templates/email_index', {into: 'adminEmail'});
  }
});
