/**
  This controller supports the "share" link controls

  @class ShareController
  @extends Discourse.Controller
  @namespace Discourse
  @module Discourse
**/
Discourse.ShareController = Discourse.Controller.extend({

  needs: ['topic'],

  // Close the share controller
  actions: {
    close: function() {
      this.set('link', '');
      this.set('postNumber', '');
      return false;
    }
  },

  shareLinks: function() {
    return Discourse.SiteSettings.share_links.split('|').map(function(i) {
      if( Discourse.ShareLink.supportedTargets.indexOf(i) >= 0 ) {
        return Discourse.ShareLink.create({target: i, link: this.get('link'), topicTitle: this.get('controllers.topic.title')});
      } else {
        return null;
      }
    }, this).compact();
  }.property('link'),

  sharePopup: function(target, url) {
    window.open(url, '', 'menubar=no,toolbar=no,resizable=yes,scrollbars=yes,width=600,height=' + Discourse.ShareLink.popupHeight(target));
    return false;
  }

});