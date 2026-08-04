import type { TemplateOnlyComponent } from "@ember/component/template-only";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { gt } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import ChannelDetail from "./channel-detail";
import flashOnUpdate from "./flash-on-update";
import { formatMs, relativeShortTime } from "./format";
import type { channelSummaries } from "./instrumentation";
import SortableHeader, {
  type MessageBusSort,
  type SortColumn,
} from "./sortable-header";

type ChannelSummary = ReturnType<typeof channelSummaries>[number];

interface ChannelsTableSignature {
  Args: {
    /** Filtered, sorted channel summaries to display. */
    rows: ChannelSummary[];
    /** Active sort configuration. */
    sort: MessageBusSort;
    /** Clock value used for relative timestamps. */
    now: number;
    /** Whether filtering is active when the row set is empty. */
    filtered: boolean;
    /** Reports whether a channel's detail row is open. */
    isExpanded: (channel: string) => boolean;
    /** Toggles a channel's detail row. */
    onToggle: (channel: string) => void;
    /** Changes or reverses the active sort column. */
    onSort: (column: SortColumn) => void;
  };
  Element: HTMLTableElement;
}

const ChannelsTable: TemplateOnlyComponent<ChannelsTableSignature> = <template>
  <table class="dev-tools-message-bus__channels" ...attributes>
    <thead>
      <tr>
        <SortableHeader
          @column="channel"
          @label={{i18n "dev_tools.message_bus.column_channel"}}
          @sort={{@sort}}
          @onSort={{@onSort}}
          class="dev-tools-message-bus__column --channel"
        />
        <SortableHeader
          @column="subscribers"
          @label={{i18n "dev_tools.message_bus.column_subscribers"}}
          @titleLabel={{i18n "dev_tools.message_bus.column_subscribers_title"}}
          @sort={{@sort}}
          @onSort={{@onSort}}
          class="dev-tools-message-bus__column --subscribers"
        />
        <SortableHeader
          @column="messages"
          @label={{i18n "dev_tools.message_bus.column_messages"}}
          @titleLabel={{i18n "dev_tools.message_bus.column_messages_title"}}
          @sort={{@sort}}
          @onSort={{@onSort}}
          class="dev-tools-message-bus__column --messages"
        />
        <SortableHeader
          @column="last-message"
          @label={{i18n "dev_tools.message_bus.column_last_message"}}
          @titleLabel={{i18n "dev_tools.message_bus.column_last_message_title"}}
          @sort={{@sort}}
          @onSort={{@onSort}}
          class="dev-tools-message-bus__column --last-message"
        />
        <SortableHeader
          @column="errors"
          @label={{i18n "dev_tools.message_bus.column_errors"}}
          @titleLabel={{i18n "dev_tools.message_bus.column_errors_title"}}
          @sort={{@sort}}
          @onSort={{@onSort}}
          class="dev-tools-message-bus__column --errors --col-extra"
        />
        <SortableHeader
          @column="slowest"
          @label={{i18n "dev_tools.message_bus.column_slowest"}}
          @titleLabel={{i18n "dev_tools.message_bus.column_slowest_title"}}
          @sort={{@sort}}
          @onSort={{@onSort}}
          class="dev-tools-message-bus__column --slowest --col-extra"
        />
      </tr>
    </thead>
    <tbody>
      {{#each @rows key="channel" as |row|}}
        {{! eslint-disable-next-line ember/template-no-invalid-interactive }}
        <tr
          class={{dConcatClass
            "dev-tools-message-bus__row"
            (if row.duplicated "--duplicated")
            (if row.errors "--failing")
            (if (@isExpanded row.channel) "--expanded")
          }}
          {{flashOnUpdate row.lastMessageAt}}
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
              "dev-tools-message-bus__cell --subscribers"
              (if row.subscriberCount "" "--zero")
            }}
          >
            {{row.subscriberCount}}
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
              "dev-tools-message-bus__cell --errors --col-extra"
              (if row.errors "--danger" "--zero")
            }}
          >
            {{row.errors}}
          </td>
          <td
            class={{dConcatClass
              "dev-tools-message-bus__cell --slowest --col-extra"
              (if row.slowestMs "" "--zero")
              (if (gt row.slowestMs 16) "--over-budget")
            }}
            title={{if
              (gt row.slowestMs 16)
              (i18n "dev_tools.message_bus.slowest_over_budget_title")
            }}
          >
            {{formatMs row.slowestMs}}
          </td>
        </tr>
        {{#if (@isExpanded row.channel)}}
          <ChannelDetail @channel={{row.channel}} @now={{@now}} />
        {{/if}}
      {{else}}
        <tr>
          <td class="dev-tools-message-bus__empty" colspan="6">
            {{i18n
              (if
                @filtered
                "dev_tools.message_bus.no_matches"
                "dev_tools.message_bus.no_channels"
              )
            }}
          </td>
        </tr>
      {{/each}}
    </tbody>
  </table>
</template>;

export default ChannelsTable;
