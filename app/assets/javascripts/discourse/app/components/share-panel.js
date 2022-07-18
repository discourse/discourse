import Component from "@ember/component";
import I18n from "I18n";
import Sharing from "discourse/lib/sharing";
import { alias } from "@ember/object/computed";
import discourseComputed from "discourse-common/utils/decorators";
import { escapeExpression } from "discourse/lib/utilities";
import { isEmpty } from "@ember/utils";
import discourseLater from "discourse-common/lib/later";

export default Component.extend({
  tagName: null,
  type: alias("panel.model.type"),
  topic: alias("panel.model.topic"),
  privateCategory: alias("panel.model.topic.category.read_restricted"),

  @discourseComputed("topic.{isPrivateMessage,invisible,category}")
  sources(topic) {
    const privateContext =
      this.siteSettings.login_required ||
      (topic && topic.isPrivateMessage) ||
      (topic && topic.invisible) ||
      this.privateCategory;
    return Sharing.activeSources(this.siteSettings.share_links, privateContext);
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
    if (shareUrl.startsWith("/")) {
      const location = window.location;
      shareUrl = `${location.protocol}//${location.host}${shareUrl}`;
    }

    return encodeURI(shareUrl);
  },

  didInsertElement() {
    this._super(...arguments);
    discourseLater(() => {
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
        title: this.get("topic.title"),
      });
    },
  },
});
