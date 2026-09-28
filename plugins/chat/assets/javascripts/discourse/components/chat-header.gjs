import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import HomeLogo from "discourse/components/header/home-logo";
import getURL from "discourse/lib/get-url";
import { and } from "discourse/truth-helpers";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class ChatHeader extends Component {
  @service chatStateManager;
  @service mobileTabBar;
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

  // The tab bar already leads back to the forum, so chat keeps the site's own
  // header and hands its navbar a place in it.
  get sharesSiteHeader() {
    return this.mobileTabBar.enabled;
  }

  get isChatOpen() {
    return this.router.currentURL.startsWith("/chat");
  }

  get forumLink() {
    return getURL(this.previousURL ?? this.router.rootURL);
  }

  @action
  registerNavbarSlot(element) {
    this.chatStateManager.headerNavbarSlot = element;
  }

  @action
  unregisterNavbarSlot() {
    this.chatStateManager.headerNavbarSlot = null;
  }

  #updatePreviousURL() {
    if (!this.isChatOpen) {
      this.previousURL = this.router.currentURL;
    }
  }

  <template>
    {{#if (and this.shouldRender this.sharesSiteHeader)}}
      <div class="c-header --site">
        <HomeLogo @minimized={{this.mobileTabBar.isNestedPage}} />
        <div
          class="c-header__navbar-slot"
          {{didInsert this.registerNavbarSlot}}
          {{willDestroy this.unregisterNavbarSlot}}
        ></div>
      </div>
    {{else if this.shouldRender}}
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
