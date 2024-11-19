import Component from "@glimmer/component";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { i18n } from "discourse-i18n";
import {
  UnreadChannelsIndicator,
  UnreadDirectMessagesIndicator,
  UnreadThreadsIndicator,
} from "discourse/plugins/chat/discourse/components/chat/footer/unread-indicator";

export default class ChatFooter extends Component {
  @service router;
  @service chat;
  @service chatHistory;
  @service siteSettings;
  @service site;
  @service currentUser;
  @service chatChannelsManager;
  @service chatStateManager;

  get includeThreads() {
    if (!this.siteSettings.chat_threads_enabled) {
      return false;
    }
    return this.chatChannelsManager.hasThreadedChannels;
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
        <DButton
          @route="chat.channels"
          @icon="comments"
          @translatedLabel={{i18n "chat.channel_list.title"}}
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
            @translatedLabel={{i18n "chat.direct_messages.title"}}
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
            @translatedLabel={{i18n "chat.my_threads.title"}}
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
      </nav>
    {{/if}}
  </template>
}
