/**
  Allows users to customize site content

  @class AdminSiteContentEditRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminSiteContentEditRoute = Discourse.Route.extend({

  serialize: function(model) {
    return {content_type: model.get('content_type')};
  },

  model: function(params) {
    var list = Discourse.SiteContentType.findAll();

    return list.then(function(items) {
      return items.findProperty("content_type", params.content_type);
    });
  },

  renderTemplate: function() {
    this.render('admin/templates/site_content_edit', {into: 'admin/templates/site_contents'});
  },

  exit: function() {
    this._super();
    this.render('admin/templates/site_contents_empty', {into: 'admin/templates/site_contents'});
  },

  setupController: function(controller, model) {

    controller.set('loaded', false);
    controller.setProperties({
      model: model,
      saving: false,
      saved: false
    });

    Discourse.SiteContent.find(model.get('content_type')).then(function (sc) {
      controller.set('content', sc);
      controller.set('loaded', true);
    });
  }


});
