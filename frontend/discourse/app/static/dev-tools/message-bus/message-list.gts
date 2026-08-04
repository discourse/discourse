import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { i18n } from "discourse-i18n";
import type { ObservedMessage } from "./instrumentation";
import MessageItem from "./message-item";

const PAGE_SIZE = 100;

interface MessageListSignature {
  Args: {
    /** Messages in the order they should be rendered. */
    messages: ObservedMessage[];
    /** Clock value shared by every relative timestamp in the list. */
    now: number;
    /** Whether each message includes its channel name. */
    showChannel?: boolean;
  };
  Element: HTMLDivElement;
}

export default class MessageList extends Component<MessageListSignature> {
  @tracked visibleCount = PAGE_SIZE;

  get hasOlder() {
    return this.args.messages.length > this.visibleCount;
  }

  get visibleMessages() {
    return this.args.messages.slice(0, this.visibleCount);
  }

  @action
  showOlder() {
    this.visibleCount += PAGE_SIZE;
  }

  <template>
    <div class="dev-tools-message-bus__message-list" ...attributes>
      <ul class="dev-tools-message-bus__messages">
        {{#each this.visibleMessages key="seq" as |message|}}
          <MessageItem
            @message={{message}}
            @now={{@now}}
            @showChannel={{@showChannel}}
          />
        {{else}}
          <li class="dev-tools-message-bus__empty">
            {{i18n "dev_tools.message_bus.no_messages"}}
          </li>
        {{/each}}
      </ul>
      {{#if this.hasOlder}}
        <button
          type="button"
          class="btn btn-default dev-tools-message-bus__show-older"
          {{on "click" this.showOlder}}
        >
          {{i18n "dev_tools.message_bus.show_older"}}
        </button>
      {{/if}}
    </div>
  </template>
}
