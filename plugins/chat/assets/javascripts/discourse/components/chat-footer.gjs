import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import i18n from "discourse-common/helpers/i18n";
import {
  UnreadChannelsIndicator,
  UnreadDirectMessagesIndicator,
  UnreadThreadsIndicator,
} from "discourse/plugins/chat/discourse/components/chat/footer/unread-indicator";

export default class ChatFooter extends Component {
  @service router;
  @service chat;
  @service siteSettings;
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

  get shouldRenderFooter() {
    return (
      this.chatStateManager.hasPreloadedChannels &&
      (this.includeThreads || this.directMessagesEnabled)
    );
  }

  <template>
    {{#if this.shouldRenderFooter}}
      <nav class="c-footer">
        <DButton
          @action={{fn @onClickTab "channels"}}
          @icon="comments"
          @translatedLabel={{i18n "chat.channel_list.title"}}
          aria-label={{i18n "chat.channel_list.aria_label"}}
          id="c-footer-channels"
          class={{concatClass
            "btn-flat"
            "c-footer__item"
            (if (eq @activeTab "channels") "--active")
          }}
        >
          <UnreadChannelsIndicator />
        </DButton>

        {{#if this.directMessagesEnabled}}
          <DButton
            @action={{fn @onClickTab "direct-messages"}}
            @icon="users"
            @translatedLabel={{i18n "chat.direct_messages.title"}}
            aria-label={{i18n "chat.direct_messages.aria_label"}}
            id="c-footer-direct-messages"
            class={{concatClass
              "btn-flat"
              "c-footer__item"
              (if (eq @activeTab "direct-messages") "--active")
            }}
          >
            <UnreadDirectMessagesIndicator />
          </DButton>
        {{/if}}

        {{#if this.includeThreads}}
          <DButton
            @action={{fn @onClickTab "threads"}}
            @icon="discourse-threads"
            @translatedLabel={{i18n "chat.my_threads.title"}}
            aria-label={{i18n "chat.my_threads.aria_label"}}
            id="c-footer-threads"
            class={{concatClass
              "btn-flat"
              "c-footer__item"
              (if (eq @activeTab "threads") "--active")
            }}
          >
            <UnreadThreadsIndicator />
          </DButton>
        {{/if}}
      </nav>
    {{/if}}
  </template>
}
