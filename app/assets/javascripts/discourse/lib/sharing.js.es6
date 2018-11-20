/**
  If you want to add a new sharing source to Discourse, you can do so like this:

  ```javascript
    import Sharing from 'discourse/lib/sharing';

    Sharing.addSource({

      // This id must be present in the `share_links` site setting too
      id: 'twitter',

      // The icon that will be displayed, choose between icon name `icon` and custom HTML `htmlIcon`.
      // When both provided, prefer `icon`
      icon: 'twitter-square'
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

let _sources = {};
let _customSharingIds = [];

export default {
  // allows to by pass site settings and add a sharing id through plugin api
  // useful for theme components for example when only few users want to add
  // sharing to a specific third party
  addSharingId(id) {
    _customSharingIds.push(id);
  },

  addSource(source) {
    // backwards compatibility for plugins
    if (source.faIcon) {
      source.icon = source.faIcon.replace("fa-", "");
      delete source.faIcon;
    }

    _sources[source.id] = source;
  },

  activeSources(linksSetting = "") {
    return linksSetting
      .split("|")
      .concat(_customSharingIds)
      .map(s => _sources[s])
      .compact();
  },

  _reset() {
    _sources = {};
    _customSharingIds = [];
  }
};
