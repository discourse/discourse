import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
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
          @route={{@route}}
          @models={{@routeModels}}
          class="c-navbar__back-button no-text btn-transparent btn"
          title={{this.title}}
        >
          {{#if (has-block)}}
            {{yield}}
          {{else}}
            {{icon this.icon}}
          {{/if}}
          {{#if this.site.mobileView}}
            <ChatHeaderIconUnreadIndicator
              @urgentCount={{@urgentCount}}
              @unreadCount={{@unreadCount}}
              @indicatorPreference={{@indicatorPreference}}
            />
          {{/if}}
        </LinkTo>
      {{else}}
        <LinkTo
          @route={{this.targetRoute}}
          class="c-navbar__back-button no-text btn-transparent btn"
          title={{this.title}}
        >
          {{#if (has-block)}}
            {{yield}}
          {{else}}
            {{icon this.icon}}
          {{/if}}
          {{#if this.site.mobileView}}
            <ChatHeaderIconUnreadIndicator
              @urgentCount={{@urgentCount}}
              @unreadCount={{@unreadCount}}
              @indicatorPreference={{@indicatorPreference}}
            />
          {{/if}}
        </LinkTo>
      {{/if}}

    {{/if}}
  </template>
}
