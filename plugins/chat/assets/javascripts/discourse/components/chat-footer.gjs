import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import { modifier } from "ember-modifier";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { popupAjaxError } from "discourse/lib/ajax-error";
import i18n from "discourse-common/helpers/i18n";
import eq from "truth-helpers/helpers/eq";

export default class ChatFooter extends Component {
  @service router;
  @service chat;
  @service chatApi;

  @tracked threadsEnabled = false;

  updateThreadCount = modifier(() => {
    const ajax = this.chatApi.userThreadCount();

    ajax
      .then((result) => {
        this.threadsEnabled = result.thread_count > 0;
      })
      .catch((error) => {
        popupAjaxError(error);
      });

    return () => {
      ajax?.abort();
    };
  });

  get directMessagesEnabled() {
    return this.chat.userCanAccessDirectMessages;
  }

  get shouldRenderFooter() {
    return this.directMessagesEnabled || this.threadsEnabled;
  }

  <template>
    {{#if this.shouldRenderFooter}}
      <nav class="c-footer" {{this.updateThreadCount}}>
        {{#if this.directMessagesEnabled}}
          <DButton
            @route="chat.direct-messages"
            @class={{concatClass
              "btn-flat"
              "c-footer__item"
              (if
                (eq this.router.currentRouteName "chat.direct-messages")
                "--active"
              )
            }}
            @icon="users"
            @id="c-footer-direct-messages"
            @translatedLabel={{i18n "chat.direct_messages.title"}}
            aria-label={{i18n "chat.direct_messages.aria_label"}}
          />
        {{/if}}

        <DButton
          @route="chat.channels"
          @class={{concatClass
            "btn-flat"
            "c-footer__item"
            (if (eq this.router.currentRouteName "chat.channels") "--active")
          }}
          @icon="comments"
          @id="c-footer-channels"
          @translatedLabel={{i18n "chat.channel_list.title"}}
          aria-label={{i18n "chat.channel_list.aria_label"}}
        />

        {{#if this.threadsEnabled}}
          <DButton
            @route="chat.threads"
            @class={{concatClass
              "btn-flat"
              "c-footer__item"
              (if (eq this.router.currentRouteName "chat.threads") "--active")
            }}
            @icon="discourse-threads"
            @id="c-footer-threads"
            @translatedLabel={{i18n "chat.my_threads.title"}}
            aria-label={{i18n "chat.my_threads.aria_label"}}
          />
        {{/if}}
      </nav>
    {{/if}}
  </template>
}
