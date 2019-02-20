import { escapeExpression } from "discourse/lib/utilities";
import { longDateNoYear } from "discourse/lib/formatter";
import { default as computed } from "ember-addons/ember-computed-decorators";
import Sharing from "discourse/lib/sharing";

export default Ember.Component.extend({
  tagName: null,

  date: Ember.computed.alias("panel.model.date"),
  type: Ember.computed.alias("panel.model.type"),
  postNumber: Ember.computed.alias("panel.model.postNumber"),
  postId: Ember.computed.alias("panel.model.postId"),
  topic: Ember.computed.alias("panel.model.topic"),

  @computed
  sources() {
    return Sharing.activeSources(this.siteSettings.share_links);
  },

  @computed("date")
  postDate(date) {
    return date ? longDateNoYear(new Date(date)) : null;
  },

  @computed("type", "postNumber", "postDate", "topic.title")
  shareTitle(type, postNumber, postDate, topicTitle) {
    topicTitle = escapeExpression(topicTitle);

    if (type === "topic") {
      return I18n.t("share.topic", { topicTitle });
    }
    if (postNumber) {
      return I18n.t("share.post", { postNumber, postDate });
    }
    return I18n.t("share.topic", { topicTitle });
  },

  @computed("topic.shareUrl")
  shareUrl(shareUrl) {
    if (Ember.isEmpty(shareUrl)) {
      return;
    }

    // Relative urls
    if (shareUrl.indexOf("/") === 0) {
      const location = window.location;
      shareUrl = `${location.protocol}//${location.host}${shareUrl}`;
    }

    return encodeURI(shareUrl);
  },

  didInsertElement() {
    this._super(...arguments);

    const shareUrl = this.get("shareUrl");
    const $linkInput = this.$(".topic-share-url");
    const $linkForTouch = this.$(".topic-share-url-for-touch a");

    Ember.run.schedule("afterRender", () => {
      if (!this.capabilities.touch) {
        $linkForTouch.parent().remove();

        $linkInput
          .val(shareUrl)
          .select()
          .focus();
      } else {
        $linkInput.remove();

        $linkForTouch.attr("href", shareUrl).text(shareUrl);

        const range = window.document.createRange();
        range.selectNode($linkForTouch[0]);
        window.getSelection().addRange(range);
      }
    });
  },

  actions: {
    share(source) {
      const url = source.generateUrl(
        this.get("shareUrl"),
        this.get("topic.title")
      );
      const options = {
        menubar: "no",
        toolbar: "no",
        resizable: "yes",
        scrollbars: "yes",
        width: 600,
        height: source.popupHeight || 315
      };
      const stringOptions = Object.keys(options)
        .map(k => `${k}=${options[k]}`)
        .join(",");

      if (source.shouldOpenInPopup) {
        window.open(url, "", stringOptions);
      } else {
        window.open(url, "_blank");
      }
    }
  }
});
