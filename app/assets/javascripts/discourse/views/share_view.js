/**
  This view is used for rendering the "share" interface for a post

  @class ShareView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.ShareView = Discourse.View.extend({
  templateName: 'share',
  elementId: 'share-link',
  classNameBindings: ['hasLink'],

  title: (function() {
    if (this.get('controller.type') === 'topic') return Em.String.i18n('share.topic');
    return Em.String.i18n('share.post');
  }).property('controller.type'),

  hasLink: (function() {
    if (this.present('controller.link')) return 'visible';
    return null;
  }).property('controller.link'),

  linkChanged: (function() {
    if (this.present('controller.link')) {
      $('#share-link input').val(this.get('controller.link')).select().focus();
    }
  }).observes('controller.link'),

  facebookUrl: function() {
    return ("http://www.facebook.com/sharer.php?u=" + this.get('controller.link'));
  }.property('controller.link'),

  twitterUrl: function() {
    return ("http://twitter.com/home?status=" + this.get('controller.link'));
  }.property('controller.link'),

  googlePlusUrl: function() {
    return ("https://plus.google.com/share?url=" + this.get('controller.link'));
  }.property('controller.link'),

  didInsertElement: function() {
    var _this = this;
    $('html').on('click.outside-share-link', function(e) {
      if (_this.$().has(e.target).length !== 0) {
        return;
      }
      _this.get('controller').close();
      return true;
    });
    return $('html').on('click.discoure-share-link', '[data-share-url]', function(e) {
      var $currentTarget, url;
      e.preventDefault();
      $currentTarget = $(e.currentTarget);
      url = $currentTarget.data('share-url');
      /* Relative urls
      */

      if (url.indexOf("/") === 0) {
        url = window.location.protocol + "//" + window.location.host + url;
      }
      _this.get('controller').shareLink(e, url);
      return false;
    });
  },

  willDestroyElement: function() {
    $('html').off('click.discoure-share-link');
    $('html').off('click.outside-share-link');
  }

});


