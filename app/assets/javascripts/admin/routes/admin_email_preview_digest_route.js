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

Discourse.AdminEmailPreviewDigestRoute = Discourse.Route.extend(Discourse.ModelReady, {

  model: function() {
    return Discourse.EmailPreview.findDigest(oneWeekAgo());
  },

  modelReady: function(controller, model) {
    controller.setProperties({
      lastSeen: oneWeekAgo(),
      showHtml: true
    });
  }

});
