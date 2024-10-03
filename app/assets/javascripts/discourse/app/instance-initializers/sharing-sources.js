import Sharing from "discourse/lib/sharing";
import I18n from "discourse-i18n";

export default {
  initialize(owner) {
    const siteSettings = owner.lookup("service:site-settings");

    Sharing.addSource({
      id: "twitter",
      icon: "fab-x-twitter",
      generateUrl(link, title, quote = "") {
        const text = quote ? `"${quote}" -- ` : title;
        return `http://x.com/intent/tweet?url=${encodeURIComponent(
          link
        )}&text=${encodeURIComponent(text)}`;
      },
      shouldOpenInPopup: true,
      title: I18n.t("share.twitter"),
      popupHeight: 265,
    });

    Sharing.addSource({
      id: "facebook",
      icon: "fab-facebook",
      title: I18n.t("share.facebook"),
      generateUrl(link, title, quote = "") {
        const fb_url = siteSettings.facebook_app_id
          ? `https://www.facebook.com/dialog/share?app_id=${
              siteSettings.facebook_app_id
            }&quote=${encodeURIComponent(quote)}&href=`
          : "https://www.facebook.com/sharer.php?u=";

        return `${fb_url}${encodeURIComponent(link)}`;
      },
      shouldOpenInPopup: true,
    });

    Sharing.addSource({
      id: "email",
      icon: "envelope",
      title: I18n.t("share.email"),
      generateUrl(link, title, quote = "") {
        const body = quote ? `${quote} \n\n ${link}` : link;
        return (
          "mailto:?to=&subject=" +
          encodeURIComponent("[" + siteSettings.title + "] " + title) +
          "&body=" +
          encodeURIComponent(body)
        );
      },
      showInPrivateContext: true,
    });
  },
};
