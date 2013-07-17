/**
  Previews the Email Digests

  @class AdminEmailPreviewDigest
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/

var oneWeekAgo = function() {
  return moment().subtract('days',7).format('YYYY-MM-DD');
};

Discourse.AdminEmailPreviewDigestRoute = Discourse.Route.extend({

  model: function() {
    return Discourse.EmailPreview.findDigest(oneWeekAgo());
  },

  afterModel: function(model) {
    var controller = this.controllerFor('adminEmailPreviewDigest');
    controller.setProperties({
      model: model,
      lastSeen: oneWeekAgo(),
      showHtml: true
    });
  }

});
