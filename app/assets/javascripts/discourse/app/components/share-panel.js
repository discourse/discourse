import I18n from "I18n";
import { isEmpty } from "@ember/utils";
import { alias } from "@ember/object/computed";
import Component from "@ember/component";
import { escapeExpression } from "discourse/lib/utilities";
import discourseComputed from "discourse-common/utils/decorators";
import Sharing from "discourse/lib/sharing";
import { later } from "@ember/runloop";

export default Component.extend({
  tagName: null,

  type: alias("panel.model.type"),

  topic: alias("panel.model.topic"),

  @discourseComputed
  sources() {
    return Sharing.activeSources(this.siteSettings.share_links);
  },

  @discourseComputed("type", "topic.title")
  shareTitle(type, topicTitle) {
    topicTitle = escapeExpression(topicTitle);
    return I18n.t("share.topic_html", { topicTitle });
  },

  @discourseComputed("panel.model.shareUrl", "topic.shareUrl")
  shareUrl(forcedShareUrl, shareUrl) {
    shareUrl = forcedShareUrl || shareUrl;

    if (isEmpty(shareUrl)) {
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
    later(() => {
      if (this.element) {
        const textArea = this.element.querySelector(".topic-share-url");
        textArea.style.height = textArea.scrollHeight + "px";
        textArea.focus();
        textArea.setSelectionRange(0, this.shareUrl.length);
      }
    }, 200);
  },

  actions: {
    share(source) {
      Sharing.shareSource(source, {
        url: this.shareUrl,
        title: this.get("topic.title")
      });
    }
  }
});
