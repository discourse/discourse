/**
  Allows users to customize site content

  @class AdminSiteContentsRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminSiteContentsRoute = Discourse.Route.extend({

  model: function() {
    return Discourse.SiteContentType.findAll();
  },

  renderTemplate: function(controller, model) {
    this.render('admin/templates/site_contents', {into: 'admin/templates/admin'});
    this.render('admin/templates/site_contents_empty', {into: 'admin/templates/site_contents'});
  },

  setupController: function(controller, model) {
    controller.set('model', model);
  }
});

