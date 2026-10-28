import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import getURL from "discourse/lib/get-url";
import { discoveryHomepageRoute } from "discourse/lib/homepage-router-overrides";
import { defaultHomepage } from "discourse/lib/utilities";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class ChatHeader extends Component {
  @service site;
  @service siteSettings;
  @service router;

  @tracked previousURL;

  title = i18n("chat.back_to_forum");
  heading = i18n("chat.heading");

  constructor() {
    super(...arguments);
    this.router.on("routeDidChange", this, this.#updatePreviousURL);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.router.off("routeDidChange", this, this.#updatePreviousURL);
  }

  get shouldRender() {
    return (
      this.siteSettings.chat_enabled && this.site.mobileView && this.isChatOpen
    );
  }

  get isChatOpen() {
    return this.router.currentURL.startsWith("/chat");
  }

  get forumLink() {
    if (this.previousURL) {
      return getURL(this.previousURL);
    }

    // `/` would lead straight back into chat
    if (defaultHomepage() === "chat") {
      return getURL(this.router.urlFor(discoveryHomepageRoute()));
    }

    return getURL(this.router.rootURL);
  }

  #updatePreviousURL() {
    if (!this.router.currentRouteName?.startsWith("chat")) {
      this.previousURL = this.router.currentURL;
    }
  }

  <template>
    {{#if this.shouldRender}}
      <div class="c-header">
        <a
          class="btn-flat back-to-forum"
          href={{this.forumLink}}
          title={{this.title}}
        >
          {{dIcon "arrow-left"}}
          {{this.title}}
        </a>

        <LinkTo class="c-heading" @route="chat.index">{{this.heading}}</LinkTo>
      </div>
    {{else}}
      {{yield}}
    {{/if}}
  </template>
}
