import Component from "@glimmer/component";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { eq } from "discourse/truth-helpers";
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

  get includeStarred() {
    return this.chatChannelsManager.hasStarredChannels;
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

  <template>
    {{#if this.shouldRenderFooter}}
      <nav class="c-footer">
        {{#if this.includeStarred}}
          <DButton
            @route="chat.starred-channels"
            @icon="star"
            @label="chat.starred"
            aria-label={{i18n "chat.starred"}}
            id="c-footer-starred"
            class={{concatClass
              "btn-transparent"
              "c-footer__item"
              (if (eq this.currentRouteName "chat.starred-channels") "--active")
            }}
          >
            <UnreadStarredIndicator />
          </DButton>
        {{/if}}

        <DButton
          @route="chat.channels"
          @icon="comments"
          @label="chat.channel_list.title"
          aria-label={{i18n "chat.channel_list.aria_label"}}
          id="c-footer-channels"
          class={{concatClass
            "btn-transparent"
            "c-footer__item"
            (if (eq this.currentRouteName "chat.channels") "--active")
          }}
        >
          <UnreadChannelsIndicator />
        </DButton>

        {{#if this.directMessagesEnabled}}
          <DButton
            @route="chat.direct-messages"
            @icon="users"
            @label="chat.direct_messages.title"
            aria-label={{i18n "chat.direct_messages.aria_label"}}
            id="c-footer-direct-messages"
            class={{concatClass
              "btn-transparent"
              "c-footer__item"
              (if (eq this.currentRouteName "chat.direct-messages") "--active")
            }}
          >
            <UnreadDirectMessagesIndicator />
          </DButton>
        {{/if}}

        {{#if this.includeThreads}}
          <DButton
            @route="chat.threads"
            @icon="discourse-threads"
            @label="chat.my_threads.title"
            aria-label={{i18n "chat.my_threads.aria_label"}}
            id="c-footer-threads"
            class={{concatClass
              "btn-transparent"
              "c-footer__item"
              (if (eq this.currentRouteName "chat.threads") "--active")
            }}
          >
            <UnreadThreadsIndicator />
          </DButton>
        {{/if}}

        {{#if this.siteSettings.chat_search_enabled}}
          <DButton
            @route="chat.search"
            @icon="magnifying-glass"
            @label="chat.search.short_title"
            id="c-footer-search"
            class={{concatClass
              "btn-transparent"
              "c-footer__item"
              (if (eq this.currentRouteName "chat.search") "--active")
            }}
          />
        {{/if}}
      </nav>
    {{/if}}
  </template>
}
