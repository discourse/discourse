/**
  This controller previews an email digest

  @class AdminEmailPreviewDigestController
  @extends Discourse.ObjectController
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminEmailPreviewDigestController = Discourse.ObjectController.extend(Discourse.Presence, {

  refresh: function() {
    var model = this.get('model');
    var controller = this;
    controller.set('loading', true);
    Discourse.EmailPreview.findDigest(this.get('lastSeen')).then(function (email) {
      model.setProperties(email.getProperties('html_content', 'text_content'));
      controller.set('loading', false);
    })
  }

});
