import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import ChatHeaderIconUnreadIndicator from "discourse/plugins/chat/discourse/components/chat/header/icon/unread-indicator";

export default class ChatNavbarBackButton extends Component {
  @service chatStateManager;
  @service site;

  get icon() {
    return this.args.icon ?? "chevron-left";
  }

  get title() {
    return this.args.title ?? i18n("chat.browse.back");
  }

  get targetRoute() {
    return this.args.route ?? "chat";
  }

  get showBackButton() {
    return (
      this.chatStateManager.isDrawerExpanded ||
      this.chatStateManager.isFullPageActive
    );
  }

  <template>
    {{#if this.showBackButton}}
      {{#if @routeModels}}
        <LinkTo
          class="c-navbar__back-button no-text btn-transparent btn"
          title={{this.title}}
          @models={{@routeModels}}
          @route={{@route}}
        >
          {{#if (has-block)}}
            {{yield}}
          {{else}}
            {{dIcon this.icon}}
          {{/if}}
          {{#if this.site.mobileView}}
            <ChatHeaderIconUnreadIndicator
              @hasUnreadThreads={{@hasUnreadThreads}}
              @indicatorPreference={{@indicatorPreference}}
              @mentionCount={{@mentionCount}}
              @unreadCount={{@unreadCount}}
              @urgentCount={{@urgentCount}}
            />
          {{/if}}
        </LinkTo>
      {{else}}
        <LinkTo
          class="c-navbar__back-button no-text btn-transparent btn"
          title={{this.title}}
          @route={{this.targetRoute}}
        >
          {{#if (has-block)}}
            {{yield}}
          {{else}}
            {{dIcon this.icon}}
          {{/if}}
          {{#if this.site.mobileView}}
            <ChatHeaderIconUnreadIndicator
              @hasUnreadThreads={{@hasUnreadThreads}}
              @indicatorPreference={{@indicatorPreference}}
              @mentionCount={{@mentionCount}}
              @unreadCount={{@unreadCount}}
              @urgentCount={{@urgentCount}}
            />
          {{/if}}
        </LinkTo>
      {{/if}}

    {{/if}}
  </template>
}
