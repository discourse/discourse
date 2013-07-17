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
    var list = this.controllerFor('adminSiteContents').get('model');

    // ember routing is fun ... this is what happens
    //
    // linkTo creates an Ember.LinkView , it marks an <a> with the class "active"
    //  if the "context" of this dynamic route is equal to the model in the linkTo
    //  the route "context" is set here, so we want to make sure we have the exact
    //  same object, from Ember we have:
    //
    //    if (handlerInfo.context !== object) { return false; }
    //
    // we could avoid this hack if Ember just compared .serialize(model) with .serialize(context)
    //
    // alternatively we could use some sort of identity map
    //
    // see also: https://github.com/emberjs/ember.js/issues/3005

    return list.findProperty("content_type", params.content_type);
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
