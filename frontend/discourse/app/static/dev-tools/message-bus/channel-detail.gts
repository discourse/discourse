import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { longDate } from "discourse/lib/formatter";
import { gt } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { formatMs, relativeShortTime, shortSource } from "./format";
import { channelDetail, logSubscriberToConsole } from "./instrumentation";
import MessageList from "./message-list";

interface ChannelDetailSignature {
  Args: {
    /** Exact channel whose retained detail is displayed. */
    channel: string;
    /** Clock value used for relative timestamps. */
    now: number;
    /** Number of parent-table columns occupied by the detail. */
    colspan?: number;
  };
  Element: HTMLTableRowElement;
}

export default class ChannelDetail extends Component<ChannelDetailSignature> {
  get detail() {
    return channelDetail(this.args.channel);
  }

  get hasLiveSubscribers() {
    return Boolean(this.detail?.subscribers.length);
  }

  get hasPastSubscribers() {
    return Boolean(this.detail?.pastSubscribers.length);
  }

  // Invoked as template helpers, which call them without a receiver, so they
  // must be bound to reach the component.
  @action
  absoluteTime(timestamp: number | null) {
    return timestamp ? longDate(new Date(timestamp)) : undefined;
  }

  @action
  source(frame: string | null | undefined) {
    return shortSource(frame);
  }

  @action
  subscribed(timestamp: number | null) {
    return i18n("dev_tools.message_bus.subscribed", {
      when: relativeShortTime(timestamp, this.args.now),
    });
  }

  @action
  lifetime(subscribedAt: number | null, unsubscribedAt: number) {
    return subscribedAt === null
      ? i18n("dev_tools.message_bus.lifetime_unknown")
      : i18n("dev_tools.message_bus.lifetime", {
          duration: relativeShortTime(subscribedAt, unsubscribedAt),
        });
  }

  <template>
    {{#if this.detail}}
      <tr class="dev-tools-message-bus__detail-row" ...attributes>
        <td colspan={{if @colspan @colspan 6}}>
          <div class="dev-tools-message-bus__detail">
            <h3 class="dev-tools-message-bus__detail-heading">
              {{i18n "dev_tools.message_bus.subscribers"}}
            </h3>
            <ul class="dev-tools-message-bus__subscribers">
              {{#if this.hasLiveSubscribers}}
                {{#each this.detail.subscribers key="id" as |subscriber|}}
                  <li class="dev-tools-message-bus__subscriber">
                    <span class="dev-tools-message-bus__subscriber-id">
                      {{subscriber.id}}
                    </span>
                    <span class="dev-tools-message-bus__source">
                      {{if
                        (this.source subscriber.source)
                        (this.source subscriber.source)
                        (i18n "dev_tools.message_bus.source_unknown")
                      }}
                    </span>
                    <span
                      class="dev-tools-message-bus__subscribed"
                      title={{this.absoluteTime subscriber.subscribedAt}}
                    >
                      {{this.subscribed subscriber.subscribedAt}}
                    </span>
                    <span class="dev-tools-message-bus__stats">
                      <span
                        class="dev-tools-message-bus__chip"
                        title={{i18n
                          "dev_tools.message_bus.calls"
                          count=subscriber.calls
                        }}
                      >
                        {{i18n
                          "dev_tools.message_bus.calls"
                          count=subscriber.calls
                        }}
                      </span>
                      <span
                        class={{dConcatClass
                          "dev-tools-message-bus__chip"
                          (if subscriber.errors "--critical")
                        }}
                        title={{if
                          subscriber.lastError
                          subscriber.lastError
                          (i18n
                            "dev_tools.message_bus.errors"
                            count=subscriber.errors
                          )
                        }}
                      >
                        {{i18n
                          "dev_tools.message_bus.errors"
                          count=subscriber.errors
                        }}
                      </span>
                      <span
                        class={{dConcatClass
                          "dev-tools-message-bus__chip"
                          "dev-tools-message-bus__slowest"
                          (if (gt subscriber.slowestMs 16) "--critical")
                        }}
                        title={{if
                          (gt subscriber.slowestMs 16)
                          (i18n
                            "dev_tools.message_bus.slowest_over_budget_title"
                          )
                          (i18n "dev_tools.message_bus.column_slowest_title")
                        }}
                      >
                        {{formatMs subscriber.slowestMs}}
                        ms
                      </span>
                    </span>
                    <button
                      type="button"
                      class="dev-tools-message-bus__log-source"
                      aria-label={{i18n "dev_tools.message_bus.log_source"}}
                      title={{i18n "dev_tools.message_bus.log_source"}}
                      {{on "click" (fn logSubscriberToConsole subscriber.id)}}
                    >
                      {{dIcon "code"}}
                    </button>
                  </li>
                {{/each}}
              {{else if this.hasPastSubscribers}}
                {{#each this.detail.pastSubscribers key="seq" as |subscriber|}}
                  <li
                    class="dev-tools-message-bus__subscriber dev-tools-message-bus__past-subscriber"
                  >
                    <span class="dev-tools-message-bus__source">
                      {{if
                        (this.source subscriber.source)
                        (this.source subscriber.source)
                        (i18n "dev_tools.message_bus.source_unknown")
                      }}
                    </span>
                    <span class="dev-tools-message-bus__lifetime">
                      {{this.lifetime
                        subscriber.subscribedAt
                        subscriber.unsubscribedAt
                      }}
                    </span>
                    <span class="dev-tools-message-bus__stats">
                      <span class="dev-tools-message-bus__chip">
                        {{i18n
                          "dev_tools.message_bus.calls"
                          count=subscriber.calls
                        }}
                      </span>
                      <span
                        class={{dConcatClass
                          "dev-tools-message-bus__chip"
                          (if subscriber.errors "--critical")
                        }}
                      >
                        {{i18n
                          "dev_tools.message_bus.errors"
                          count=subscriber.errors
                        }}
                      </span>
                    </span>
                  </li>
                {{/each}}
              {{else}}
                <li class="dev-tools-message-bus__empty">
                  {{i18n "dev_tools.message_bus.no_subscribers"}}
                </li>
              {{/if}}
            </ul>

            <h3 class="dev-tools-message-bus__detail-heading">
              {{i18n
                "dev_tools.message_bus.messages_heading"
                count=this.detail.messageCount
              }}
            </h3>
            <MessageList @messages={{this.detail.messages}} @now={{@now}} />
          </div>
        </td>
      </tr>
    {{/if}}
  </template>
}
