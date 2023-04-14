/**
  If you want to add a new sharing source to Discourse, you can do so like this:

  ```javascript
    import Sharing from 'discourse/lib/sharing';

    Sharing.addSource({
      // This id must be present in the `share_links` site setting too
      id: 'twitter',

      // The icon that will be displayed, choose between icon name `icon` and custom HTML `htmlIcon`.
      // When both provided, prefer `icon`
      icon: 'twitter-square',
      htmlIcon: '<img src="example.com/example.jpg">',

      // A callback for generating the remote link from the `link` and `title`
      generateUrl(link, title) {
        return "http://twitter.com/intent/tweet?url=" + encodeURIComponent(link) + "&text=" + encodeURIComponent(title);
      },

      // If provided, handle by custom javascript rather than default url open
      clickHandler(link, title) {
        alert("Hello!")
      },

      // If true, opens in a popup of `popupHeight` size. If false it's opened in a new tab
      shouldOpenInPopup: true,
      popupHeight: 265,

      // If true, will show the sharing service in PMs and login_required sites
      showInPrivateContext: false
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

  shareSource(source, data) {
    if (source.clickHandler) {
      source.clickHandler(data.url, data.title);
    } else {
      const url = source.generateUrl(data.url, data.title, data.quote);
      const options = {
        menubar: "no",
        toolbar: "no",
        resizable: "yes",
        scrollbars: "yes",
        width: 600,
        height: source.popupHeight || 315,
      };
      const stringOptions = Object.keys(options)
        .map((k) => `${k}=${options[k]}`)
        .join(",");

      if (source.shouldOpenInPopup) {
        window.open(url, "", stringOptions);
      } else if (source.id === "email") {
        window.location.href = url;
      } else {
        window.open(url, "_blank");
      }
    }
  },

  activeSources(linksSetting = "", privateContext = false) {
    const sources = linksSetting
      .split("|")
      .concat(_customSharingIds)
      .map((s) => _sources[s])
      .compact();

    return privateContext
      ? sources.filter((s) => s.showInPrivateContext)
      : sources;
  },

  _reset() {
    _sources = {};
    _customSharingIds = [];
  },
};
