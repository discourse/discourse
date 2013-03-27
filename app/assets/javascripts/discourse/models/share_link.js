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
    return Discourse.ShareLink.urlFor(this.get('target'), this.get('link'), this.get('topicTitle'));
  }.property('target', 'link', 'topicTitle'),

  title: function() {
    return Em.String.i18n("share." + this.get('target'));
  }.property('target'),

  iconClass: function() {
    return Discourse.ShareLink.iconClasses[this.get('target')];
  }.property('target')

});

Discourse.ShareLink.reopenClass({

  supportedTargets: ['twitter', 'facebook', 'google+'],

  urlFor: function(target,link,title) {
    switch(target) {
      case 'twitter':
        return this.twitterUrl(link,title);
      case 'facebook':
        return this.facebookUrl(link,title);
      case 'google+':
        return this.googlePlusUrl(link);
    }
  },

  twitterUrl: function(link, title) {
    return ("http://twitter.com/intent/tweet?url=" + encodeURIComponent(link) + "&text=" + encodeURIComponent(title) );
  },

  facebookUrl: function(link, title) {
    return ("http://www.facebook.com/sharer.php?u=" + encodeURIComponent(link) + '&t=' + encodeURIComponent(title));
  },

  googlePlusUrl: function(link) {
    return ("https://plus.google.com/share?url=" + encodeURIComponent(link));
  },

  iconClasses: {
    twitter: 'icon-twitter',
    facebook: 'icon-facebook-sign',
    'google+': 'icon-google-plus'
  },

  popupHeights: {
    twitter: 265,
    facebook: 315,
    'google+': 600
  },

  popupHeight: function(target) {
    return (this.popupHeights[target] || 315);
  }
});