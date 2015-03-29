/**
  If you want to add a new sharing source to Discourse, you can do so like this:

  ```javascript
    import Sharing from 'discourse/lib/sharing';

    Sharing.addSource({

      // This id must be present in the `share_links` site setting too
      id: 'twitter',

      // The icon that will be displayed, choose between font awesome class name `faIcon` and custom HTML `htmlIcon`.
      // When both provided, prefer `faIcon`
      faIcon: 'fa-twitter-square'
      htmlIcon: '<img src="example.com/example.jpg">',

      // A callback for generating the remote link from the `link` and `title`
      generateUrl: function(link, title) {
        return "http://twitter.com/intent/tweet?url=" + encodeURIComponent(link) + "&text=" + encodeURIComponent(title);
      },

      // If true, opens in a popup of `popupHeight` size. If false it's opened in a new tab
      shouldOpenInPopup: true,
      popupHeight: 265
    });
  ```
**/

var _sources = {};

export default {
  addSource(source) {
    _sources[source.id] = source;
  },

  activeSources(linksSetting) {
    return linksSetting.split('|').map(s => _sources[s]).compact();
  }
};
