import I18n from "I18n";
import Sharing from "discourse/lib/sharing";

export default {
  name: "sharing-sources",

  initialize(container) {
    let siteSettings = container.lookup("site-settings:main");

    Sharing.addSource({
      id: "twitter",
      icon: "fab-twitter-square",
      generateUrl(link, title) {
        return (
          "http://twitter.com/intent/tweet?url=" +
          encodeURIComponent(link) +
          "&text=" +
          encodeURIComponent(title)
        );
      },
      shouldOpenInPopup: true,
      title: I18n.t("share.twitter"),
      popupHeight: 265
    });

    Sharing.addSource({
      id: "facebook",
      icon: "fab-facebook",
      title: I18n.t("share.facebook"),
      generateUrl(link, title) {
        return (
          "http://www.facebook.com/sharer.php?u=" +
          encodeURIComponent(link) +
          "&t=" +
          encodeURIComponent(title)
        );
      },
      shouldOpenInPopup: true
    });

    Sharing.addSource({
      id: "email",
      icon: "envelope-square",
      title: I18n.t("share.email"),
      generateUrl(link, title) {
        return (
          "mailto:?to=&subject=" +
          encodeURIComponent(`[${siteSettings.title}] ${title}`) +
          "&body=" +
          encodeURIComponent(link)
        );
      }
    });
  }
};
