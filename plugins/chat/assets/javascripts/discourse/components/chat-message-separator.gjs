import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { modifier } from "ember-modifier";
import concatClass from "discourse/helpers/concat-class";
import { i18n } from "discourse-i18n";

const IS_PINNED_CLASS = "is-pinned";

export default class ChatMessageSeparator extends Component {
  track = modifier((element) => {
    const intersectionObserver = new IntersectionObserver(
      ([entry]) => {
        if (
          entry.isIntersecting &&
          entry.intersectionRatio < 1 &&
          entry.boundingClientRect.y < entry.intersectionRect.y
        ) {
          entry.target.classList.add(IS_PINNED_CLASS);
        } else {
          entry.target.classList.remove(IS_PINNED_CLASS);
        }
      },
      { threshold: [0, 1] }
    );

    intersectionObserver.observe(element);

    return () => {
      intersectionObserver?.disconnect();
    };
  });

  @action
  onDateClick() {
    return this.args.fetchMessagesByDate?.(this.firstMessageOfTheDayAt);
  }

  @cached
  get firstMessageOfTheDayAt() {
    const message = this.args.message;

    if (!message.previousMessage) {
      return this.#startOfDay(message.createdAt);
    }

    if (
      !this.#areDatesOnSameDay(
        message.previousMessage.createdAt,
        message.createdAt
      )
    ) {
      return this.#startOfDay(message.createdAt);
    }
  }

  @cached
  get formattedFirstMessageDate() {
    if (this.firstMessageOfTheDayAt) {
      return this.#calendarDate(this.firstMessageOfTheDayAt);
    }
  }

  #areDatesOnSameDay(a, b) {
    return (
      a.getFullYear() === b.getFullYear() &&
      a.getMonth() === b.getMonth() &&
      a.getDate() === b.getDate()
    );
  }

  #startOfDay(date) {
    return moment(date).startOf("day").format();
  }

  #calendarDate(date) {
    return moment(date).calendar(moment(), {
      sameDay: `[${i18n("chat.chat_message_separator.today")}]`,
      lastDay: `[${i18n("chat.chat_message_separator.yesterday")}]`,
      lastWeek: "LL",
      sameElse: "LL",
    });
  }

  <template>
    {{#if this.formattedFirstMessageDate}}
      <div
        class={{concatClass
          "chat-message-separator-date"
          (if @message.newest "with-last-visit")
        }}
        role="button"
        {{on "click" this.onDateClick passive=true}}
      >
        <div class="chat-message-separator__text-container" {{this.track}}>
          <span class="chat-message-separator__text">
            {{this.formattedFirstMessageDate}}

            {{#if @message.newest}}
              <span class="chat-message-separator__last-visit">
                <span
                  class="chat-message-separator__last-visit-separator"
                >-</span>
                {{i18n "chat.last_visit"}}
              </span>
            {{/if}}
          </span>
        </div>
      </div>

      <div class="chat-message-separator__line-container">
        <div class="chat-message-separator__line"></div>
      </div>
    {{else if @message.newest}}
      <div class="chat-message-separator-new">
        <div class="chat-message-separator__text-container">
          <span class="chat-message-separator__text">
            {{i18n "chat.last_visit"}}
          </span>
        </div>

        <div class="chat-message-separator__line-container">
          <div class="chat-message-separator__line"></div>
        </div>
      </div>
    {{/if}}
  </template>
}
