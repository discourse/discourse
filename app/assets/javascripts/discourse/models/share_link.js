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

  serviceIcon: function() {
    return Discourse.ShareLink.serviceIcons[this.get('target')];
  }.property('target'),

  openInPopup: function() {
    return( Discourse.ShareLink.shouldOpenInPopup[this.get('target')] );
  }.property('target')

});

Discourse.ShareLink.reopenClass({
  supportedTargets: [],
  urlFor: {},
  serviceIcons: {},
  popupHeights: {},
  shouldOpenInPopup: {},

  addTarget: function(id, object) {
    this.supportedTargets.push(id);
    this.urlFor[id] = object.generateUrl;
    this.serviceIcons[id] = object.serviceIcon;
    this.popupHeights[id] = object.popupHeight || 315;
    this.shouldOpenInPopup[id] = object.shouldOpenInPopup;
  },

  popupHeight: function(target) {
    return (this.popupHeights[target] || 315);
  }
});

(function() {
  Discourse.ShareLink.addTarget('twitter', {
    serviceIcon: '<i class="fa fa-twitter-square"></i>',
    generateUrl: function(link, title) {
      return ("http://twitter.com/intent/tweet?url=" + encodeURIComponent(link) + "&text=" + encodeURIComponent(title) );
    },
    shouldOpenInPopup: true,
    popupHeight: 265
  });

  Discourse.ShareLink.addTarget('facebook', {
    serviceIcon: '<i class="fa fa-facebook-square"></i>',
    generateUrl: function(link, title) {
      return ("http://www.facebook.com/sharer.php?u=" + encodeURIComponent(link) + '&t=' + encodeURIComponent(title));
    },
    shouldOpenInPopup: true,
    popupHeight: 315
  });

  Discourse.ShareLink.addTarget('google+', {
    serviceIcon: '<i class="fa fa-google-plus-square"></i>',
    generateUrl: function(link) {
      return ("https://plus.google.com/share?url=" + encodeURIComponent(link));
    },
    shouldOpenInPopup: true,
    popupHeight: 600
  });

  Discourse.ShareLink.addTarget('email', {
    serviceIcon: '<i class="fa fa-envelope-square"></i>',
    generateUrl: function(link, title) {
      return ("mailto:?to=&subject=" + encodeURIComponent('[' + Discourse.SiteSettings.title + '] ' + title) + "&body=" + encodeURIComponent(link));
    },
    shouldOpenInPopup: false
  });

  Discourse.ShareLink.addTarget('blogger', {
    serviceIcon: '<i class="zocial zocial-blogger"></i>',
    generateUrl: function(link, title) {
      return ("https://www.blogger.com/blog-this.g?u=" + encodeURIComponent(link) + "&n=" + encodeURIComponent(title) + "&t=" + encodeURIComponent(title));
    },
    shouldOpenInPopup: true,
    popupHeight: 600
  });

  Discourse.ShareLink.addTarget('reddit', {
    serviceIcon: '<i class="fa fa-reddit-square"></i>',
    generateUrl: function(link, title) {
      return ("http://www.reddit.com/submit?url=" + encodeURIComponent(link) + "&title=" + encodeURIComponent(title));
    },
    shouldOpenInPopup: true,
    popupHeight: 600
  });

  Discourse.ShareLink.addTarget('linkedin', {
    serviceIcon: '<i class="fa fa-linkedin-square"></i>',
    generateUrl: function(link, title) {
      return ("http://www.linkedin.com/shareArticle?mini=true&url=" + encodeURIComponent(link) + "&title=" + encodeURIComponent(title) + "&summary=" + encodeURIComponent(title) + "&source=" + encodeURIComponent(link));
    },
    shouldOpenInPopup: true,
    popupHeight: 600
  });

  Discourse.ShareLink.addTarget('tumblr', {
    serviceIcon: '<i class="fa fa-tumblr-square"></i>',
    generateUrl: function(link, title) {
      return ("http://www.tumblr.com/share/link?url=" + encodeURIComponent(link) + "&title=" + encodeURIComponent(title));
    },
    shouldOpenInPopup: true,
    popupHeight: 500
  });

})();
