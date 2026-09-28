import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DHorizontalOverflowNav from "discourse/ui-kit/d-horizontal-overflow-nav";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import {
  UnreadChannelsIndicator,
  UnreadDirectMessagesIndicator,
  UnreadStarredIndicator,
  UnreadThreadsIndicator,
} from "discourse/plugins/chat/discourse/components/chat/footer/unread-indicator";

export default class ChatFooter extends Component {
  @service chat;
  @service chatHistory;
  @service siteSettings;
  @service site;
  @service chatChannelsManager;
  @service chatStateManager;
  @service currentUser;
  @service mobileTabBar;

  get includeStarred() {
    return this.currentUser && this.chatChannelsManager.hasStarredChannels;
  }

  get includeSearch() {
    return this.currentUser && this.siteSettings.chat_search_enabled;
  }

  get includeThreads() {
    if (!this.siteSettings.chat_threads_enabled) {
      return false;
    }
    return this.chatChannelsManager.shouldShowMyThreads;
  }

  get directMessagesEnabled() {
    return this.chat.userCanAccessDirectMessages;
  }

  get currentRouteName() {
    const routeName = this.chatHistory.currentRoute?.name;
    return routeName === "chat" ? "chat.channels" : routeName;
  }

  get enabledRouteCount() {
    return [
      this.includeStarred,
      this.includeThreads,
      this.directMessagesEnabled,
      this.siteSettings.enable_public_channels,
    ].filter(Boolean).length;
  }

  get shouldRenderFooter() {
    return (
      (this.site.mobileView || this.chatStateManager.isDrawerExpanded) &&
      this.chatStateManager.hasPreloadedChannels &&
      this.enabledRouteCount > 1
    );
  }

  get items() {
    return [
      this.includeStarred && {
        id: "c-footer-starred",
        route: "chat.starred-channels",
        icon: "star",
        label: "chat.starred",
        ariaLabel: "chat.starred",
        indicator: UnreadStarredIndicator,
      },
      {
        id: "c-footer-channels",
        route: "chat.channels",
        icon: "comments",
        label: "chat.channel_list.title",
        ariaLabel: "chat.channel_list.aria_label",
        indicator: UnreadChannelsIndicator,
      },
      this.directMessagesEnabled && {
        id: "c-footer-direct-messages",
        route: "chat.direct-messages",
        icon: "users",
        label: "chat.direct_messages.title",
        ariaLabel: "chat.direct_messages.aria_label",
        indicator: UnreadDirectMessagesIndicator,
      },
      this.includeThreads && {
        id: "c-footer-threads",
        route: "chat.threads",
        icon: "discourse-threads",
        label: "chat.my_threads.title",
        ariaLabel: "chat.my_threads.aria_label",
        indicator: UnreadThreadsIndicator,
      },
      this.includeSearch && {
        id: "c-footer-search",
        route: "chat.search",
        icon: "magnifying-glass",
        label: "chat.search.short_title",
        ariaLabel: "chat.search.aria_label",
      },
    ].filter(Boolean);
  }

  <template>
    {{#if this.shouldRenderFooter}}
      {{! The site's tab bar holds the bottom edge, so these become pills up top }}
      {{#if this.mobileTabBar.enabled}}
        <div class="c-footer --pills">
          <DHorizontalOverflowNav>
            {{#each this.items key="id" as |item|}}
              <li>
                <LinkTo
                  class={{if (eq this.currentRouteName item.route) "active"}}
                  id={{item.id}}
                  @route={{item.route}}
                >
                  {{i18n item.label}}
                  {{#if item.indicator}}
                    <item.indicator />
                  {{/if}}
                </LinkTo>
              </li>
            {{/each}}
          </DHorizontalOverflowNav>
        </div>
      {{else}}
        <nav class="c-footer">
          {{#each this.items key="id" as |item|}}
            <DButton
              aria-label={{i18n item.ariaLabel}}
              class={{dConcatClass
                "btn-transparent"
                "c-footer__item"
                (if (eq this.currentRouteName item.route) "--active")
              }}
              id={{item.id}}
              @icon={{item.icon}}
              @label={{item.label}}
              @route={{item.route}}
            >
              {{#if item.indicator}}
                <item.indicator />
              {{/if}}
            </DButton>
          {{/each}}
        </nav>
      {{/if}}
    {{/if}}
  </template>
}
