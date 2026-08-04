import type { TemplateOnlyComponent } from "@ember/component/template-only";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import ChannelDetail from "./channel-detail";
import { relativeShortTime } from "./format";
import type { channelSummaries } from "./instrumentation";

type ChannelSummary = ReturnType<typeof channelSummaries>[number];

interface ClosedChannelsTableSignature {
  Args: {
    /** Closed channel summaries, ordered by closure recency. */
    rows: ChannelSummary[];
    /** Clock value used for relative timestamps. */
    now: number;
    /** Reports whether a channel's detail row is open. */
    isExpanded: (channel: string) => boolean;
    /** Toggles a channel's detail row. */
    onToggle: (channel: string) => void;
  };
  Element: HTMLTableElement;
}

const ClosedChannelsTable: TemplateOnlyComponent<ClosedChannelsTableSignature> =
  <template>
    <table class="dev-tools-message-bus__closed" ...attributes>
      <thead>
        <tr>
          <th class="dev-tools-message-bus__column --channel">
            {{i18n "dev_tools.message_bus.column_channel"}}
          </th>
          <th class="dev-tools-message-bus__column --messages">
            {{i18n "dev_tools.message_bus.column_messages"}}
          </th>
          <th class="dev-tools-message-bus__column --last-message">
            {{i18n "dev_tools.message_bus.column_last_message"}}
          </th>
          <th class="dev-tools-message-bus__column --closed-ago">
            {{i18n "dev_tools.message_bus.column_closed"}}
          </th>
        </tr>
      </thead>
      <tbody>
        {{#each @rows key="channel" as |row|}}
          {{! eslint-disable-next-line ember/template-no-invalid-interactive }}
          <tr
            class={{dConcatClass
              "dev-tools-message-bus__row --closed"
              (if (@isExpanded row.channel) "--expanded")
            }}
            {{on "click" (fn @onToggle row.channel)}}
          >
            <td class="dev-tools-message-bus__cell --channel">
              <button
                type="button"
                class="dev-tools-message-bus__channel-name"
                aria-expanded={{if (@isExpanded row.channel) "true" "false"}}
                aria-label={{i18n
                  "dev_tools.message_bus.expand_channel"
                  channel=row.channel
                }}
                title={{i18n
                  "dev_tools.message_bus.expand_channel"
                  channel=row.channel
                }}
              >
                {{row.channel}}
              </button>
            </td>
            <td
              class={{dConcatClass
                "dev-tools-message-bus__cell --messages"
                (if row.messageCount "" "--zero")
              }}
            >
              {{row.messageCount}}
            </td>
            <td
              class={{dConcatClass
                "dev-tools-message-bus__cell --last-message"
                (if row.lastMessageAt "" "--zero")
              }}
            >
              {{if
                row.lastMessageAt
                (relativeShortTime row.lastMessageAt @now)
                "-"
              }}
            </td>
            <td
              class={{dConcatClass
                "dev-tools-message-bus__cell --closed-ago"
                (if row.closedAt "" "--zero")
              }}
            >
              {{if row.closedAt (relativeShortTime row.closedAt @now) "-"}}
            </td>
          </tr>
          {{#if (@isExpanded row.channel)}}
            <ChannelDetail
              @channel={{row.channel}}
              @now={{@now}}
              @colspan={{4}}
            />
          {{/if}}
        {{/each}}
      </tbody>
    </table>
  </template>;

export default ClosedChannelsTable;
