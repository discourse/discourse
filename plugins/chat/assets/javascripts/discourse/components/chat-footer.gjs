import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import i18n from "discourse-common/helpers/i18n";
import eq from "truth-helpers/helpers/eq";

export default class ChatFooter extends Component {
  @service site;
  @service router;
  @service chat;
  @service chatApi;
  @service chatChannelsManager;

  @tracked threadsEnabled = false;

  constructor() {
    super(...arguments);
    this.userThreadCount();
  }

  async userThreadCount() {
    await this.chatApi.userThreadCount().then((result) => {
      this.threadsEnabled = result.thread_count > 0;
    });
  }

  get directMessagesEnabled() {
    return (
      this.chat.userCanDirectMessage ||
      this.chatChannelsManager.directMessageChannels?.length > 0
    );
  }

  get shouldRenderFooter() {
    return this.directMessagesEnabled || this.threadsEnabled;
  }

  <template>
    <nav class="c-footer">
      {{#if this.shouldRenderFooter}}
        {{#if this.directMessagesEnabled}}
          <DButton
            @route="chat.index"
            @class={{concatClass
              "btn-flat c-footer__item"
              (if (eq this.router.currentRouteName "chat.index") "--active")
            }}
            @icon="users"
            @translatedLabel={{i18n "chat.direct_messages.title"}}
            aria-label={{i18n "chat.direct_messages.aria_label"}}
          />
        {{/if}}

        <DButton
          @route="chat.channels"
          @class={{concatClass
            "btn-flat c-footer__item"
            (if (eq this.router.currentRouteName "chat.channels") "--active")
          }}
          @icon="comments"
          @translatedLabel={{i18n "chat.channel_list.title"}}
          aria-label={{i18n "chat.channel_list.aria_label"}}
        />

        {{#if this.threadsEnabled}}
          <DButton
            @route="chat.threads"
            @class={{concatClass
              "btn-flat c-footer__item"
              (if (eq this.router.currentRouteName "chat.threads") "--active")
            }}
            @icon="discourse-threads"
            @translatedLabel={{i18n "chat.my_threads.title"}}
            aria-label={{i18n "chat.my_threads.aria_label"}}
          />
        {{/if}}
      {{/if}}
    </nav>
  </template>
}
