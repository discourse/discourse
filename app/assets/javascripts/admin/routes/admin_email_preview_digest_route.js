/**
  Previews the Email Digests

  @class AdminEmailPreviewDigest
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/

Discourse.AdminEmailPreviewDigestRoute = Discourse.Route.extend({

  model: function() {
    return Discourse.EmailPreview.findDigest();
  },

  afterModel: function(model) {
    var controller = this.controllerFor('adminEmailPreviewDigest');
    controller.setProperties({
      model: model,
      lastSeen: moment().subtract(7, 'days').format('YYYY-MM-DD'),
      showHtml: true
    });
  }

});
