/**
  Previews the Email Digests

  @class AdminEmailPreviewDigest
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/

var oneWeekAgo = function() {
  // TODO: Take out due to being evil sugar js?
  return Date.create(7 + ' days ago', 'en').format('{yyyy}-{MM}-{dd}');
}

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
