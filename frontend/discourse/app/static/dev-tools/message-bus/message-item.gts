import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { longDate } from "discourse/lib/formatter";
import discourseLater from "discourse/lib/later";
import { clipboardCopy } from "discourse/lib/utilities";
import DHighlightedCode from "discourse/ui-kit/d-highlighted-code";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import I18n, { i18n } from "discourse-i18n";
import {
  messageBytes,
  messagePreview,
  prettyJson,
  relativeShortTime,
} from "./format";
import type { ObservedMessage } from "./instrumentation";

interface MessageItemSignature {
  Args: {
    /** Captured message to display. */
    message: ObservedMessage;
    /** Clock value used to render relative timestamps and freshness. */
    now: number;
    /** Whether the channel name is included in the message summary. */
    showChannel?: boolean;
  };
  Element: HTMLLIElement;
}

export default class MessageItem extends Component<MessageItemSignature> {
  @tracked copied = false;
  @tracked expanded = false;

  get isFresh() {
    return this.args.now - this.args.message.receivedAt < 1000;
  }

  get exactTime() {
    return longDate(new Date(this.args.message.receivedAt));
  }

  get payload() {
    return prettyJson(this.args.message.data);
  }

  get preview() {
    return messagePreview(this.args.message);
  }

  get size() {
    return I18n.toHumanSize(messageBytes(this.args.message), {});
  }

  get time() {
    return relativeShortTime(this.args.message.receivedAt, this.args.now);
  }

  @action
  async copyPayload() {
    await clipboardCopy(this.payload);
    this.copied = true;

    discourseLater(() => {
      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      this.copied = false;
    }, 1500);
  }

  @action
  toggle(event: MouseEvent) {
    if (
      event.target instanceof Element &&
      event.target.closest(".dev-tools-message-bus__payload")
    ) {
      return;
    }

    this.expanded = !this.expanded;
  }

  <template>
    {{! eslint-disable-next-line ember/template-no-invalid-interactive }}
    <li
      class={{dConcatClass
        "dev-tools-message-bus__message"
        (if this.isFresh "--fresh")
      }}
      ...attributes
      {{on "click" this.toggle}}
    >
      <button
        type="button"
        class="dev-tools-message-bus__message-toggle"
        aria-expanded={{if this.expanded "true" "false"}}
        aria-label={{i18n
          (if
            this.expanded
            "dev_tools.message_bus.hide_payload"
            "dev_tools.message_bus.show_payload"
          )
        }}
        title={{i18n
          (if
            this.expanded
            "dev_tools.message_bus.hide_payload"
            "dev_tools.message_bus.show_payload"
          )
        }}
      >
        {{dIcon (if this.expanded "chevron-down" "chevron-right")}}
      </button>
      {{#if @showChannel}}
        <span class="dev-tools-message-bus__message-channel">
          {{@message.channel}}
        </span>
      {{/if}}
      {{#if @message.messageId}}
        <span
          class="dev-tools-message-bus__message-id"
          title={{i18n
            "dev_tools.message_bus.message_id_title"
            id=@message.messageId
          }}
        >
          #{{@message.messageId}}
        </span>
      {{/if}}
      <span class="dev-tools-message-bus__message-preview">
        {{this.preview}}
      </span>
      <span
        class="dev-tools-message-bus__message-size"
        title={{i18n "dev_tools.message_bus.message_size_title"}}
      >
        {{this.size}}
      </span>
      <span
        class="dev-tools-message-bus__message-time"
        title={{this.exactTime}}
      >
        {{this.time}}
      </span>
      {{#if this.expanded}}
        <div class="dev-tools-message-bus__payload">
          <button
            type="button"
            class="dev-tools-message-bus__copy-payload"
            aria-label={{i18n "dev_tools.message_bus.copy_payload"}}
            title={{i18n "dev_tools.message_bus.copy_payload"}}
            {{on "click" this.copyPayload}}
          >
            {{dIcon (if this.copied "check" "copy")}}
          </button>
          <DHighlightedCode @code={{this.payload}} @lang="json" />
        </div>
      {{/if}}
    </li>
  </template>
}
