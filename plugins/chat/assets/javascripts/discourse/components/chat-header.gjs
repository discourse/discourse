import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import icon from "discourse-common/helpers/d-icon";
import getURL from "discourse-common/lib/get-url";
import I18n from "discourse-i18n";

export default class ChatHeader extends Component {
  @service site;
  @service siteSettings;
  @service router;

  @tracked previousURL;

  title = I18n.t("chat.back_to_forum");
  heading = I18n.t("chat.heading");

  constructor() {
    super(...arguments);
    this.router.on("routeDidChange", this, this.#updatePreviousURL);
  }

  get shouldRender() {
    return (
      this.siteSettings.chat_enabled && this.site.mobileView && this.isChatOpen
    );
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.router.off("routeDidChange", this, this.#updatePreviousURL);
  }

  get isChatOpen() {
    return this.router.currentURL.startsWith("/chat");
  }

  get forumLink() {
    return getURL(this.previousURL ?? this.router.rootURL);
  }

  #updatePreviousURL() {
    if (!this.isChatOpen) {
      this.previousURL = this.router.currentURL;
    }
  }

  <template>
    {{#if this.shouldRender}}
      <div class="c-header">
        <a
          href={{this.forumLink}}
          class="btn-flat back-to-forum"
          title={{this.title}}
        >
          {{icon "arrow-left"}}
          {{this.title}}
        </a>

        <LinkTo @route="chat.index" class="c-heading">{{this.heading}}</LinkTo>
      </div>
    {{else}}
      {{yield}}
    {{/if}}
  </template>
}
