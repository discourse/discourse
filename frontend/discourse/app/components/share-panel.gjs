/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { action, computed, set } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { isEmpty } from "@ember/utils";
import DTextarea from "discourse/components/d-textarea";
import ShareSource from "discourse/components/share-source";
import discourseLater from "discourse/lib/later";
import Sharing from "discourse/lib/sharing";
import { escapeExpression } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default class SharePanel extends Component {
  tagName = null;

  @computed("panel.model.type")
  get type() {
    return this.panel?.model?.type;
  }

  set type(value) {
    set(this, "panel.model.type", value);
  }

  @computed("panel.model.topic")
  get topic() {
    return this.panel?.model?.topic;
  }

  set topic(value) {
    set(this, "panel.model.topic", value);
  }

  @computed("panel.model.topic.category.read_restricted")
  get privateCategory() {
    return this.panel?.model?.topic?.category?.read_restricted;
  }

  set privateCategory(value) {
    set(this, "panel.model.topic.category.read_restricted", value);
  }

  @computed("topic.{isPrivateMessage,invisible,category}")
  get sources() {
    const privateContext =
      this.siteSettings.login_required ||
      (this.topic && this.topic?.isPrivateMessage) ||
      (this.topic && this.topic?.invisible) ||
      this.privateCategory;
    return Sharing.activeSources(this.siteSettings.share_links, privateContext);
  }

  @computed("type", "topic.title")
  get shareTitle() {
    const topicTitle = escapeExpression(this.topic?.title);
    return i18n("share.topic_html", { topicTitle });
  }

  @computed("panel.model.shareUrl", "topic.shareUrl")
  get shareUrl() {
    let shareUrl = this.panel?.model?.shareUrl || this.topic?.shareUrl;

    if (isEmpty(shareUrl)) {
      return;
    }

    // Relative urls
    if (shareUrl.startsWith("/")) {
      const location = window.location;
      shareUrl = `${location.protocol}//${location.host}${shareUrl}`;
    }

    return encodeURI(shareUrl);
  }

  didInsertElement() {
    super.didInsertElement(...arguments);
    discourseLater(() => {
      if (this.element) {
        const textArea = this.element.querySelector(".topic-share-url");
        textArea.style.height = textArea.scrollHeight + "px";
        textArea.focus();
        textArea.setSelectionRange(0, this.shareUrl.length);
      }
    }, 200);
  }

  @action
  share(source) {
    Sharing.shareSource(source, {
      url: this.shareUrl,
      title: this.topic.get("title"),
    });
  }

  <template>
    <div class="header">
      <h3 class="title">{{htmlSafe this.shareTitle}}</h3>
    </div>

    <div class="body">
      <DTextarea
        @value={{this.shareUrl}}
        @aria-label={{i18n "share.url"}}
        class="topic-share-url"
      />

      <div class="sources">
        {{#each this.sources as |source|}}
          <ShareSource @source={{source}} @action={{this.share}} />
        {{/each}}
      </div>
    </div>
  </template>
}
