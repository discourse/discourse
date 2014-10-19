/**
  A data model representing a link to share a post on a 3rd party site,
  like Twitter, Facebook, and Google+.

  @class ShareLink
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.ShareLink = Discourse.Model.extend({

  href: function() {
    return Discourse.ShareLink.urlFor[this.get('target')](this.get('link'), this.get('topicTitle'));
  }.property('target', 'link', 'topicTitle'),

  title: Discourse.computed.i18n('target', 'share.%@'),

  iconClass: function() {
    return Discourse.ShareLink.iconClasses[this.get('target')];
  }.property('target'),

  openInPopup: function() {
    return( Discourse.ShareLink.shouldOpenInPopup[this.get('target')] );
  }.property('target')

});

Discourse.ShareLink.reopenClass({
  supportedTargets: [],
  urlFor: {},
  iconClasses: {},
  popupHeights: {},
  shouldOpenInPopup: {},

  addTarget: function(id, object) {
    var self = this;
    self.supportedTargets.push(id);
    self.urlFor[id] = object.generateUrl;
    self.iconClasses[id] = object.iconClass;
    self.popupHeights[id] = object.popupHeight || 315;
    self.shouldOpenInPopup[id] = object.shouldOpenInPopup;
  },

  popupHeight: function(target) {
    return (this.popupHeights[target] || 315);
  }
});

(function() {
  Discourse.ShareLink.addTarget('twitter', {
    iconClass: 'fa-twitter-square',
    generateUrl: function(link, title) {
      return ("http://twitter.com/intent/tweet?url=" + encodeURIComponent(link) + "&text=" + encodeURIComponent(title) );
    },
    shouldOpenInPopup: true,
    popupHeight: 265
  });

  Discourse.ShareLink.addTarget('facebook', {
    iconClass: 'fa-facebook-square',
    generateUrl: function(link, title) {
      return ("http://www.facebook.com/sharer.php?u=" + encodeURIComponent(link) + '&t=' + encodeURIComponent(title));
    },
    shouldOpenInPopup: true,
    popupHeight: 315
  });

  Discourse.ShareLink.addTarget('google+', {
    iconClass: 'fa-google-plus-square',
    generateUrl: function(link) {
      return ("https://plus.google.com/share?url=" + encodeURIComponent(link));
    },
    shouldOpenInPopup: true,
    popupHeight: 600
  });

  Discourse.ShareLink.addTarget('email', {
    iconClass: 'fa-envelope-square',
    generateUrl: function(link, title) {
      return ("mailto:?to=&subject=" + encodeURIComponent('[' + Discourse.SiteSettings.title + '] ' + title) + "&body=" + encodeURIComponent(link));
    },
    shouldOpenInPopup: false
  });
})();
