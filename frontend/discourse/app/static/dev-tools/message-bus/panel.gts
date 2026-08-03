import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { registerDestructor } from "@ember/destroyable";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import type Owner from "@ember/owner";
import { service } from "@ember/service";
import type DialogService from "discourse/dialog-holder/services/dialog";
import ChannelsTable from "discourse/static/dev-tools/message-bus/channels-table";
import ClosedChannelsTable from "discourse/static/dev-tools/message-bus/closed-channels-table";
import {
  channelSummaries,
  clearCaptured,
  globalMessages,
  setCapturePaused,
  summary,
} from "discourse/static/dev-tools/message-bus/instrumentation";
import MessageList from "discourse/static/dev-tools/message-bus/message-list";
import SettingsMenu from "discourse/static/dev-tools/message-bus/settings-menu";
import type {
  MessageBusSort,
  SortColumn,
} from "discourse/static/dev-tools/message-bus/sortable-header";
import devToolsState from "discourse/static/dev-tools/state";
import { eq } from "discourse/truth-helpers";
import DFilterInput from "discourse/ui-kit/d-filter-input";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const TOOL_ID = "message-bus";
const REFRESH_INTERVAL = 1000;
const DEFAULT_SORT: MessageBusSort = { column: "last-message", asc: false };
const SORT_COLUMNS: SortColumn[] = [
  "channel",
  "subscribers",
  "messages",
  "last-message",
  "errors",
  "slowest",
];

type View = "channels" | "stream";
type ChannelSummary = ReturnType<typeof channelSummaries>[number];

/** Shows captured MessageBus channels, subscribers, and traffic. */
export default class MessageBusPanel extends Component {
  @service declare dialog: DialogService;

  @tracked expandedChannels = new Set<string>();
  @tracked filter = "";
  @tracked declare sort: MessageBusSort;
  @tracked declare view: View;
  #timer: ReturnType<typeof setInterval> | null = null;
  @tracked _refreshedAt = Date.now();

  constructor(owner: Owner, args: object) {
    super(owner, args);

    this.view = this.#restoreView();
    this.sort = this.#restoreSort();

    // Deliberately not an Ember runloop timer. A repeating runloop timer never
    // lets the application settle, which would hang every test that waits for
    // it. This one is outside the runloop and cancelled on teardown.
    this.#timer = setInterval(() => {
      this._refreshedAt = Date.now();
    }, REFRESH_INTERVAL);

    registerDestructor(this, () => clearInterval(this.#timer));
  }

  get captureSummary() {
    // The subscription list lives in MessageBus' own untracked array, so the
    // timer is consumed to re-read it while the panel is open.
    // eslint-disable-next-line @typescript-eslint/no-unused-expressions
    this._refreshedAt;

    return summary();
  }

  get messages() {
    const filter = this.#normalizedFilter;
    const messages = globalMessages();

    return filter
      ? messages.filter(({ channel }) =>
          channel.toLocaleLowerCase().includes(filter)
        )
      : messages;
  }

  get isFiltered() {
    return this.filter.length > 0;
  }

  get now() {
    return this._refreshedAt;
  }

  get filteredRows() {
    // Consumed for the same reason as in `captureSummary`: a subscription
    // registered after render would otherwise never appear until unrelated
    // tracked state happened to change.
    // eslint-disable-next-line @typescript-eslint/no-unused-expressions
    this._refreshedAt;

    const filter = this.#normalizedFilter;
    return filter
      ? channelSummaries().filter(({ channel }) =>
          channel.toLocaleLowerCase().includes(filter)
        )
      : channelSummaries();
  }

  get liveRows() {
    const rows = this.filteredRows.filter(({ subscriberCount }) =>
      Boolean(subscriberCount)
    );
    const direction = this.sort.asc ? 1 : -1;

    return rows.sort((left, right) => {
      const comparison = this.#sortValue(left, right, this.sort.column);

      return comparison === 0
        ? left.channel.localeCompare(right.channel)
        : comparison * direction;
    });
  }

  get closedRows() {
    return this.filteredRows
      .filter(({ subscriberCount }) => subscriberCount === 0)
      .sort((left, right) => {
        if (left.closedAt === right.closedAt) {
          return left.channel.localeCompare(right.channel);
        }

        if (left.closedAt === null) {
          return 1;
        }

        if (right.closedAt === null) {
          return -1;
        }

        return right.closedAt - left.closedAt;
      });
  }

  get #normalizedFilter() {
    return this.filter.trim().toLocaleLowerCase();
  }

  @action
  clear() {
    this.dialog.deleteConfirm({
      message: i18n("dev_tools.message_bus.clear_confirm"),
      didConfirm: () => clearCaptured(),
      class: "dev-tools-message-bus__confirm-dialog",
    });
  }

  @action
  clearFilter() {
    this.filter = "";
  }

  @action
  isChannelExpanded(channel: string) {
    return this.expandedChannels.has(channel);
  }

  @action
  setFilter(event: Event) {
    this.filter = (event.currentTarget as HTMLInputElement).value;
  }

  @action
  setSort(column: SortColumn) {
    this.sort = {
      column,
      asc: this.sort.column === column ? !this.sort.asc : true,
    };
    devToolsState.setFlag(TOOL_ID, "sort", this.sort);
  }

  @action
  setView(view: View) {
    this.view = view;
    devToolsState.setFlag(TOOL_ID, "view", view);
  }

  @action
  toggleCapture() {
    setCapturePaused(!this.captureSummary.capturePaused);
  }

  @action
  toggleChannel(channel: string) {
    const expanded = new Set(this.expandedChannels);

    if (expanded.has(channel)) {
      expanded.delete(channel);
    } else {
      expanded.add(channel);
    }

    this.expandedChannels = expanded;
  }

  #restoreSort(): MessageBusSort {
    const stored = devToolsState.getFlag(TOOL_ID, "sort") as
      | Partial<MessageBusSort>
      | undefined;

    return stored &&
      SORT_COLUMNS.includes(stored.column as SortColumn) &&
      typeof stored.asc === "boolean"
      ? { column: stored.column as SortColumn, asc: stored.asc }
      : DEFAULT_SORT;
  }

  #restoreView(): View {
    const stored = devToolsState.getFlag(TOOL_ID, "view");
    return stored === "stream" ? "stream" : "channels";
  }

  #sortValue(left: ChannelSummary, right: ChannelSummary, column: SortColumn) {
    switch (column) {
      case "channel":
        return left.channel.localeCompare(right.channel);
      case "subscribers":
        return left.subscriberCount - right.subscriberCount;
      case "messages":
        return left.messageCount - right.messageCount;
      case "last-message":
        return (left.lastMessageAt ?? 0) - (right.lastMessageAt ?? 0);
      case "errors":
        return left.errors - right.errors;
      case "slowest":
        return left.slowestMs - right.slowestMs;
    }
  }

  <template>
    <div class="dev-tools-message-bus">
      <header class="dev-tools-message-bus__top-bar">
        <div class="dev-tools-message-bus__heading">
          <span class="dev-tools-message-bus__title">
            {{i18n "dev_tools.message_bus.title"}}
          </span>
          <div class="dev-tools-message-bus__chips">
            <span
              class={{dConcatClass
                "dev-tools-message-bus__chip --live"
                (if this.captureSummary.capturePaused "--neutral" "--success")
              }}
              title={{i18n
                (if
                  this.captureSummary.capturePaused
                  "dev_tools.message_bus.chip_paused_title"
                  "dev_tools.message_bus.chip_live_title"
                )
              }}
            >
              <span
                class={{dConcatClass
                  "dev-tools-message-bus__live-dot"
                  (if this.captureSummary.capturePaused "--paused")
                }}
                title={{i18n
                  (if
                    this.captureSummary.capturePaused
                    "dev_tools.message_bus.paused"
                    "dev_tools.message_bus.live"
                  )
                }}
              ></span>
              {{i18n
                (if
                  this.captureSummary.capturePaused
                  "dev_tools.message_bus.paused"
                  "dev_tools.message_bus.live"
                )
              }}
            </span>
            <span
              class="dev-tools-message-bus__chip --neutral --polls"
              title={{i18n "dev_tools.message_bus.chip_polls_title"}}
            >
              {{i18n
                "dev_tools.message_bus.poll_count"
                count=this.captureSummary.polls
              }}
            </span>
          </div>
        </div>

        <div class="dev-tools-message-bus__action-group">
          <button
            type="button"
            class="dev-tools-message-bus__pause dev-tools-message-bus__action"
            aria-pressed={{if this.captureSummary.capturePaused "true" "false"}}
            title={{i18n
              (if
                this.captureSummary.capturePaused
                "dev_tools.message_bus.resume"
                "dev_tools.message_bus.pause"
              )
            }}
            aria-label={{i18n
              (if
                this.captureSummary.capturePaused
                "dev_tools.message_bus.resume"
                "dev_tools.message_bus.pause"
              )
            }}
            {{on "click" this.toggleCapture}}
          >
            {{dIcon (if this.captureSummary.capturePaused "play" "pause")}}
          </button>
          <button
            type="button"
            class="dev-tools-message-bus__clear dev-tools-message-bus__action"
            title={{i18n "dev_tools.message_bus.clear"}}
            aria-label={{i18n "dev_tools.message_bus.clear"}}
            {{on "click" this.clear}}
          >
            {{dIcon "ban"}}
          </button>
          <SettingsMenu />
        </div>
      </header>

      {{#if this.captureSummary.evictedChannelCount}}
        <div class="dev-tools-message-bus__eviction-warning" role="alert">
          {{i18n
            "dev_tools.message_bus.eviction_warning"
            count=this.captureSummary.evictedChannelCount
          }}
        </div>
      {{/if}}

      <div class="dev-tools-message-bus__toolbar">
        <DFilterInput
          @value={{this.filter}}
          @filterAction={{this.setFilter}}
          @onClearInput={{this.clearFilter}}
          @icons={{hash left="magnifying-glass"}}
          placeholder={{i18n "dev_tools.message_bus.filter_placeholder"}}
        />
        <nav
          class="dev-tools-message-bus__views"
          aria-label={{i18n "dev_tools.message_bus.view"}}
        >
          <ul class="nav nav-pills">
            <li>
              <button
                type="button"
                class={{dConcatClass
                  "dev-tools-message-bus__view --channels"
                  (if (eq this.view "channels") "active")
                }}
                {{on "click" (fn this.setView "channels")}}
              >
                {{i18n "dev_tools.message_bus.tab_channels"}}
              </button>
            </li>
            <li>
              <button
                type="button"
                class={{dConcatClass
                  "dev-tools-message-bus__view --stream"
                  (if (eq this.view "stream") "active")
                }}
                {{on "click" (fn this.setView "stream")}}
              >
                {{i18n "dev_tools.message_bus.tab_stream"}}
              </button>
            </li>
          </ul>
        </nav>
      </div>

      {{#if (eq this.view "channels")}}
        <section class="dev-tools-message-bus__live-section">
          <h2 class="dev-tools-message-bus__live-heading">
            <span>{{i18n "dev_tools.message_bus.live_channels"}}</span>
            <span
              class="dev-tools-message-bus__chip --neutral --subscriptions"
              title={{i18n "dev_tools.message_bus.chip_subscriptions_title"}}
            >
              {{i18n
                "dev_tools.message_bus.subscription_count"
                count=this.captureSummary.subscriptionCount
              }}
            </span>
            <span
              class={{dConcatClass
                "dev-tools-message-bus__chip --duplicated"
                (if
                  this.captureSummary.duplicatedChannelCount
                  "--critical"
                  "--neutral"
                )
              }}
              title={{i18n "dev_tools.message_bus.chip_duplicated_title"}}
            >
              {{i18n
                "dev_tools.message_bus.duplicated_count"
                count=this.captureSummary.duplicatedChannelCount
              }}
            </span>
          </h2>
          <ChannelsTable
            @rows={{this.liveRows}}
            @sort={{this.sort}}
            @now={{this.now}}
            @filtered={{this.isFiltered}}
            @isExpanded={{this.isChannelExpanded}}
            @onToggle={{this.toggleChannel}}
            @onSort={{this.setSort}}
          />
        </section>
        {{#if this.closedRows.length}}
          <section class="dev-tools-message-bus__closed-section">
            <h2 class="dev-tools-message-bus__closed-heading">
              {{i18n
                "dev_tools.message_bus.closed_channels"
                count=this.closedRows.length
              }}
            </h2>
            <ClosedChannelsTable
              @rows={{this.closedRows}}
              @now={{this.now}}
              @isExpanded={{this.isChannelExpanded}}
              @onToggle={{this.toggleChannel}}
            />
          </section>
        {{/if}}
      {{else}}
        <div class="dev-tools-message-bus__stream">
          <MessageList
            @messages={{this.messages}}
            @now={{this.now}}
            @showChannel={{true}}
          />
        </div>
      {{/if}}
    </div>
  </template>
}
