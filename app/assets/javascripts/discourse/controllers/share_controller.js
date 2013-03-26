/**
  This controller supports the "share" link controls

  @class ShareController
  @extends Discourse.Controller
  @namespace Discourse
  @module Discourse
**/
Discourse.ShareController = Discourse.Controller.extend({

  // When the user clicks the post number, we pop up a share box
  shareLink: function(e, url) {
    var x;
    x = e.pageX - 150;
    if (x < 25) {
      x = 25;
    }
    $('#share-link').css({
      left: "" + x + "px",
      top: "" + (e.pageY - 100) + "px"
    });
    this.set('link', url);
    return false;
  },

  // Close the share controller
  close: function() {
    this.set('link', '');
    return false;
  },

  shareLinks: function() {
    return Discourse.SiteSettings.share_links.split('|').map(function(i) {
      if( Discourse.ShareLink.supportedTargets.indexOf(i) >= 0 ) {
        return Discourse.ShareLink.create({target: i, link: this.get('link')});
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