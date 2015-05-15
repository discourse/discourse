import Sharing from 'discourse/lib/sharing';

export default {
  name: 'sharing-sources',

  initialize: function() {
    // Backwards compatibility
    Discourse.ShareLink = {};
    Discourse.ShareLink.addTarget = function(id, source) {
      Ember.warn('Discourse.ShareLink.addTarget is deprecated. Import `Sharing` and call `addSource` instead.');
      source.id = id;
      Sharing.addSource(source);
    };

    Sharing.addSource({
      id: 'twitter',
      faIcon: 'fa-twitter-square',
      generateUrl: function(link, title) {
        return "http://twitter.com/intent/tweet?url=" + encodeURIComponent(link) + "&text=" + encodeURIComponent(title);
      },
      shouldOpenInPopup: true,
      title: I18n.t('share.twitter'),
      popupHeight: 265
    });

    Sharing.addSource({
      id: 'facebook',
      faIcon: 'fa-facebook-square',
      title: I18n.t('share.facebook'),
      generateUrl: function(link, title) {
        return "http://www.facebook.com/sharer.php?u=" + encodeURIComponent(link) + '&t=' + encodeURIComponent(title);
      },
      shouldOpenInPopup: true
    });

    Sharing.addSource({
      id: 'google+',
      faIcon: 'fa-google-plus-square',
      title: I18n.t('share.google+'),
      generateUrl: function(link) {
        return "https://plus.google.com/share?url=" + encodeURIComponent(link);
      },
      shouldOpenInPopup: true,
      popupHeight: 600
    });

    Sharing.addSource({
      id: 'email',
      faIcon: 'fa-envelope-square',
      title: I18n.t('share.email'),
      generateUrl: function(link, title) {
        return "mailto:?to=&subject=" + encodeURIComponent('[' + Discourse.SiteSettings.title + '] ' + title) + "&body=" + encodeURIComponent(link);
      }
    });
  }
};
