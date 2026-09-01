import Component from "@glimmer/component";
import { service } from "@ember/service";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
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

  <template>
    {{#if this.shouldRenderFooter}}
      <nav class="c-footer">
        {{#if this.includeStarred}}
          <DButton
            aria-label={{i18n "chat.starred"}}
            class={{dConcatClass
              "btn-transparent"
              "c-footer__item"
              (if (eq this.currentRouteName "chat.starred-channels") "--active")
            }}
            id="c-footer-starred"
            @icon="star"
            @label="chat.starred"
            @route="chat.starred-channels"
          >
            <UnreadStarredIndicator />
          </DButton>
        {{/if}}

        <DButton
          aria-label={{i18n "chat.channel_list.aria_label"}}
          class={{dConcatClass
            "btn-transparent"
            "c-footer__item"
            (if (eq this.currentRouteName "chat.channels") "--active")
          }}
          id="c-footer-channels"
          @icon="comments"
          @label="chat.channel_list.title"
          @route="chat.channels"
        >
          <UnreadChannelsIndicator />
        </DButton>

        {{#if this.directMessagesEnabled}}
          <DButton
            aria-label={{i18n "chat.direct_messages.aria_label"}}
            class={{dConcatClass
              "btn-transparent"
              "c-footer__item"
              (if (eq this.currentRouteName "chat.direct-messages") "--active")
            }}
            id="c-footer-direct-messages"
            @icon="users"
            @label="chat.direct_messages.title"
            @route="chat.direct-messages"
          >
            <UnreadDirectMessagesIndicator />
          </DButton>
        {{/if}}

        {{#if this.includeThreads}}
          <DButton
            aria-label={{i18n "chat.my_threads.aria_label"}}
            class={{dConcatClass
              "btn-transparent"
              "c-footer__item"
              (if (eq this.currentRouteName "chat.threads") "--active")
            }}
            id="c-footer-threads"
            @icon="discourse-threads"
            @label="chat.my_threads.title"
            @route="chat.threads"
          >
            <UnreadThreadsIndicator />
          </DButton>
        {{/if}}

        {{#if this.includeSearch}}
          <DButton
            aria-label={{i18n "chat.search.aria_label"}}
            class={{dConcatClass
              "btn-transparent"
              "c-footer__item"
              (if (eq this.currentRouteName "chat.search") "--active")
            }}
            id="c-footer-search"
            @icon="magnifying-glass"
            @label="chat.search.short_title"
            @route="chat.search"
          />
        {{/if}}
      </nav>
    {{/if}}
  </template>
}
