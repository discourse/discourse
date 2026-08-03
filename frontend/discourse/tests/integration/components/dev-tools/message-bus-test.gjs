import Component from "@glimmer/component";
import { click, fillIn, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import DialogHolder from "discourse/dialog-holder/components/dialog-holder";
import {
  activateDockTool,
  clearDockPanels,
  closeDock,
  dockState,
  registerDockPanel,
} from "discourse/static/dev-tools/dock";
import DevToolsDockHost from "discourse/static/dev-tools/dock-host";
import {
  install,
  uninstall,
} from "discourse/static/dev-tools/message-bus/instrumentation";
import MessageBusPanel from "discourse/static/dev-tools/message-bus/panel";
import devToolsState from "discourse/static/dev-tools/state";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

const TOOL_ID = "message-bus";
const FLAGS = [
  "view",
  "sort",
  "maxChannelMessages",
  "maxGlobalMessages",
  "maxTrackedChannels",
];

const DOCK = ".d-panel-dock.--context-dev-tools";
const PANEL = `${DOCK} .dev-tools-message-bus`;
const HEADER = ".dev-tools-message-bus__top-bar";
const ACTIONS = HEADER;
const MENU = ".fk-d-menu__inner-content";
const FILTER = ".dev-tools-message-bus__toolbar input";
const CHANNELS_TAB = "button.dev-tools-message-bus__view.--channels";
const STREAM_TAB = "button.dev-tools-message-bus__view.--stream";
const LIVE_TABLE = "table.dev-tools-message-bus__channels";
const CLOSED_TABLE = "table.dev-tools-message-bus__closed";
const LIVE_HEADING = ".dev-tools-message-bus__live-heading";
const CLOSED_HEADING = ".dev-tools-message-bus__closed-heading";
// Scoped to the live table, and blind to a closed row wherever it renders, so
// that a row moving between the two sections shows up as a move rather than as
// a row the helpers quietly keep finding.
const ROW = `${LIVE_TABLE} tr.dev-tools-message-bus__row:not(.--closed)`;
const CLOSED_ROW = `${CLOSED_TABLE} tr.dev-tools-message-bus__row.--closed`;
const DETAIL_ROW = "tr.dev-tools-message-bus__detail-row";
const CLOSED_DETAIL_ROW = `${CLOSED_TABLE} tr.dev-tools-message-bus__detail-row`;
const PAST_SUBSCRIBER = ".dev-tools-message-bus__past-subscriber";
const MESSAGE = ".dev-tools-message-bus__message";
const STREAM_MESSAGE = `.dev-tools-message-bus__stream ${MESSAGE}`;
const SHOW_OLDER = "button.dev-tools-message-bus__show-older";
const CHIPS = `${HEADER} .dev-tools-message-bus__chips`;
const CHIP = ".dev-tools-message-bus__chip";
const LIVE_DOT = `${CHIPS} ${CHIP}.--live .dev-tools-message-bus__live-dot`;
const PAYLOAD = ".dev-tools-message-bus__payload pre code";
const COPY_PAYLOAD =
  ".dev-tools-message-bus__payload button.dev-tools-message-bus__copy-payload";
const SORT_ICON = ".d-icon-angle-up, .d-icon-angle-down";
const COLUMNS = [
  "channel",
  "subscribers",
  "messages",
  "last-message",
  "errors",
  "slowest",
];

const CAP_CHANNEL = ".dev-tools-message-bus__cap-channel";
const CAP_GLOBAL = ".dev-tools-message-bus__cap-global";
const CAP_TRACKED = ".dev-tools-message-bus__cap-tracked";
const APPLY = `${MENU} .form-kit__button[type="submit"]`;
/** Retention cap form field names, keyed by the flag each one writes. */
const CAP_FIELDS = {
  maxChannelMessages: CAP_CHANNEL,
  maxGlobalMessages: CAP_GLOBAL,
  maxTrackedChannels: CAP_TRACKED,
};

function key(name) {
  return `dev_tools.message_bus.${name}`;
}

function fieldFor(name) {
  return `${MENU} .form-kit__field[data-name="${name}"]`;
}

async function renderPanel() {
  registerDockPanel(TOOL_ID, {
    label: "MessageBus",
    component: MessageBusPanel,
  });
  activateDockTool(TOOL_ID);

  await render(<template><DevToolsDockHost /></template>);
}

/** Renders the panel next to a dialog holder, for the flows that confirm. */
async function renderPanelWithDialog() {
  registerDockPanel(TOOL_ID, {
    label: "MessageBus",
    component: MessageBusPanel,
  });
  activateDockTool(TOOL_ID);

  await render(
    <template>
      <DevToolsDockHost />
      <DialogHolder />
    </template>
  );
}

/** One message as it arrives in a long poll response frame. */
function frame(channel, messageId, globalId, data) {
  return {
    channel,
    message_id: messageId,
    global_id: globalId,
    data,
  };
}

/**
 * Runs a fake non-chunked poll, delivering `payload` through the instrumented
 * `ajax` exactly as message-bus-client would.
 */
function deliverViaSuccess(payload) {
  const bus = window.MessageBus;
  let decorated;

  bus.ajax = (options) => {
    decorated = options;
  };
  bus.ajax({ messageBus: { chunked: false }, success: () => {} });
  return decorated.success(payload);
}

/** Delivers one message the way MessageBus calls a subscriber. */
function deliver(channel, data, globalId, messageId) {
  const entry = window.MessageBus.callbacks.find(
    (callback) => callback.channel === channel
  );
  return entry.func(data, globalId, messageId);
}

/**
 * Delivers a message recorded as having arrived at `receivedAt`.
 *
 * Two deliveries in one test otherwise land in the same millisecond, which
 * leaves nothing to order channels by recency with.
 */
function deliverAt(receivedAt, channel, data, globalId, messageId) {
  const realNow = Date.now;
  Date.now = () => receivedAt;

  try {
    return deliver(channel, data, globalId, messageId);
  } finally {
    Date.now = realNow;
  }
}

/**
 * Unsubscribes with the clock frozen, so two closures can be told apart.
 *
 * Two unsubscribes in one test otherwise land in the same millisecond, which
 * leaves nothing to order closed channels by recency with.
 */
function unsubscribeAt(closedAt, channel, handler) {
  const realNow = Date.now;
  Date.now = () => closedAt;

  try {
    return window.MessageBus.unsubscribe(channel, handler);
  } finally {
    Date.now = realNow;
  }
}

/**
 * Lets the open panel re-read MessageBus' own subscription array.
 *
 * Subscribing and unsubscribing mutate `MessageBus.callbacks` in place, and no
 * template consumes that array, so the panel otherwise repaints on its own
 * clock. Retyping the filter is the nudge a user gives it without waiting the
 * interval out.
 */
async function refreshPanel() {
  const input = document.querySelector(FILTER);
  await fillIn(input, input.value);
}

function channelNames(scope = ROW) {
  return textsOf(`${scope} .dev-tools-message-bus__channel-name`);
}

function rowFor(channel, scope = ROW) {
  return [...document.querySelectorAll(scope)].find(
    (row) =>
      row
        .querySelector(".dev-tools-message-bus__channel-name")
        ?.textContent.trim() === channel
  );
}

/** The row's channel name, which is also its expand/collapse control. */
function nameFor(channel, scope = ROW) {
  return (
    rowFor(channel, scope)?.querySelector(
      "button.dev-tools-message-bus__channel-name"
    ) ?? null
  );
}

function cell(channel, column, scope = ROW) {
  return rowFor(channel, scope).querySelector(
    `.dev-tools-message-bus__cell.--${column}`
  );
}

function textsOf(selector) {
  return [...document.querySelectorAll(selector)].map((element) =>
    element.textContent.trim()
  );
}

module("Integration | Component | dev-tools | message-bus", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    uninstall();

    this.bus = window.MessageBus;
    this.originalCallbacks = [...this.bus.callbacks];
    this.originalAjaxDescriptor = Object.getOwnPropertyDescriptor(
      this.bus,
      "ajax"
    );

    this.bus.callbacks.length = 0;
    install();
  });

  hooks.afterEach(function () {
    uninstall();
    closeDock();
    clearDockPanels();

    this.bus.callbacks.length = 0;
    this.bus.callbacks.push(...this.originalCallbacks);

    if (this.originalAjaxDescriptor) {
      Object.defineProperty(this.bus, "ajax", this.originalAjaxDescriptor);
    }

    for (const flag of FLAGS) {
      devToolsState.setFlag(TOOL_ID, flag, undefined);
    }
  });

  test("the local top bar carries the title and capture controls inside the shared dock", async function (assert) {
    await renderPanel();

    assert.dom(DOCK).exists("the shared dev-tools dock renders");
    assert.dom(PANEL).exists("the MessageBus panel renders as dock content");
    assert
      .dom(`${DOCK} [role="tablist"]`)
      .doesNotExist("one registered panel does not need a tab strip");
    assert
      .dom(`${DOCK} .d-panel-dock__close`)
      .exists("the shared dock owns its close control");
    assert.dom(`${HEADER} .dev-tools-message-bus__title`).hasText("MessageBus");

    assert
      .dom(`${ACTIONS} button.dev-tools-message-bus__pause`)
      .exists()
      .hasAttribute("aria-pressed", "false")
      .hasAttribute("title", i18n(key("pause")));
    assert
      .dom(`${ACTIONS} button.dev-tools-message-bus__clear`)
      .exists()
      .hasAttribute("title", i18n(key("clear")));
    assert
      .dom(`${ACTIONS} .dev-tools-message-bus__settings-trigger`)
      .exists()
      .hasAttribute("title", i18n(key("settings")));
    assert
      .dom(`${ACTIONS} .dev-tools-message-bus__close`)
      .doesNotExist(
        "the tab content does not duplicate the dock's close control"
      );
  });

  test("the shared close control closes the dock", async function (assert) {
    await renderPanel();
    await click(`${DOCK} .d-panel-dock__close`);

    assert.false(dockState().open, "the dock records that it is closed");
    assert.dom(DOCK).doesNotExist("the dock and its active content disappear");
  });

  test("the header chips report what the bus is doing", async function (assert) {
    this.bus.subscribe("/twice", () => {});
    this.bus.subscribe("/twice", () => {});
    this.bus.subscribe("/once", () => {});
    deliverViaSuccess([frame("/once", 1, 100, {})]);

    await renderPanel();

    assert
      .dom(".dev-tools-message-bus__status")
      .doesNotExist(
        "the counters moved into the header, so the body is all table"
      );
    assert.dom(CHIPS).exists();

    assert
      .dom(LIVE_DOT)
      .exists()
      .doesNotHaveClass("--paused")
      .hasAttribute("title", i18n(key("live")));
    assert
      .dom(`${CHIPS} ${CHIP}.--polls`)
      .hasText(i18n(key("poll_count"), { count: 1 }));

    assert.dom(`${CHIPS} ${CHIP}.--subscriptions`).doesNotExist(
      // The header describes the capture; what is subscribed describes the
      // table underneath it, and reading it two panels away from its rows is
      // how a count and a table drift apart.
      "the subscription counts belong to the table they count"
    );
    assert.dom(`${CHIPS} ${CHIP}.--duplicated`).doesNotExist();

    assert
      .dom(`${LIVE_HEADING} ${CHIP}.--subscriptions`)
      .hasText(i18n(key("subscription_count"), { count: 3 }));
    assert
      .dom(`${LIVE_HEADING} ${CHIP}.--duplicated`)
      .hasText(
        i18n(key("duplicated_count"), { count: 1 }),
        "duplication is counted per channel, not per subscription"
      )
      .hasClass(
        "--critical",
        "a duplicated channel is the thing the panel exists to surface"
      );
  });

  test("the duplicated chip stays quiet when nothing is duplicated", async function (assert) {
    this.bus.subscribe("/once", () => {});

    await renderPanel();

    assert
      .dom(`${LIVE_HEADING} ${CHIP}.--duplicated`)
      .hasText(i18n(key("duplicated_count"), { count: 0 }))
      .doesNotHaveClass(
        "--critical",
        "a healthy bus does not shout its own counters"
      );
  });

  test("the view switcher is navigation, not a tab widget", async function (assert) {
    await renderPanel();

    const channels = document.querySelector(CHANNELS_TAB);
    const stream = document.querySelector(STREAM_TAB);

    assert.dom(channels).exists();
    assert.dom(stream).exists();

    const list = channels?.closest("ul") ?? null;
    const nav = channels?.closest("nav") ?? null;

    assert
      .dom(nav)
      .exists()
      .hasAttribute("aria-label", i18n(key("view")));
    assert
      .dom(list)
      .exists()
      .hasClass("nav")
      .hasClass("nav-pills", "the switcher reuses the shared pill markup");
    assert.strictEqual(list?.parentElement, nav, "the list belongs to the nav");
    assert.strictEqual(channels?.parentElement?.tagName, "LI");
    assert.strictEqual(stream?.parentElement?.tagName, "LI");
    assert.strictEqual(channels?.parentElement?.parentElement, list);

    assert.dom(`${PANEL} [role="tablist"]`).doesNotExist();
    assert
      .dom(`${PANEL} [role="tab"]`)
      .doesNotExist(
        "these buttons swap a view rather than reveal a tab panel, so they are not tabs"
      );
    assert.dom(channels).doesNotHaveAttribute("aria-selected");
    assert.dom(stream).doesNotHaveAttribute("aria-selected");

    assert.dom(CHANNELS_TAB).hasClass("active");
    assert.dom(STREAM_TAB).doesNotHaveClass("active");

    await click(STREAM_TAB);

    assert.dom(STREAM_TAB).hasClass("active");
    assert.dom(CHANNELS_TAB).doesNotHaveClass("active");
  });

  test("a channel is one row however many subscriptions it holds", async function (assert) {
    this.bus.subscribe("/twice", () => {});
    this.bus.subscribe("/twice", () => {});
    this.bus.subscribe("/once", () => {});
    deliver("/twice", {}, 200, 1);
    deliver("/once", {}, 201, 1);
    deliver("/once", {}, 202, 2);

    await renderPanel();

    assert.dom(ROW).exists({ count: 2 }, "the table is keyed by channel");
    assert.deepEqual(channelNames(), ["/once", "/twice"]);

    assert.dom(cell("/twice", "subscribers")).hasText("2");
    assert.dom(cell("/twice", "messages")).hasText("1");
    assert.dom(cell("/once", "messages")).hasText("2");

    assert.dom(rowFor("/twice")).hasClass("--duplicated");
    assert.dom(rowFor("/once")).doesNotHaveClass("--duplicated");
    assert.dom(rowFor("/twice")).doesNotHaveClass("--failing");
  });

  test("a channel whose subscriber threw is flagged as failing", async function (assert) {
    this.bus.subscribe("/boom", () => {
      throw new Error("subscriber blew up");
    });
    this.bus.subscribe("/calm", () => {});

    assert.throws(() => deliver("/boom", {}, 300, 1));
    deliver("/calm", {}, 301, 1);

    await renderPanel();

    assert.dom(rowFor("/boom")).hasClass("--failing");
    assert.dom(cell("/boom", "errors")).hasText("1");
    assert.dom(rowFor("/calm")).doesNotHaveClass("--failing");
    assert.dom(cell("/calm", "errors")).hasText("0");
  });

  test("a numeric cell dims at zero and turns dangerous on errors", async function (assert) {
    this.bus.subscribe("/boom", () => {
      throw new Error("subscriber blew up");
    });
    this.bus.subscribe("/calm", () => {});
    this.bus.subscribe("/quiet", () => {});

    assert.throws(() => deliver("/boom", {}, 1800, 1));
    deliver("/calm", {}, 1801, 1);

    await renderPanel();

    assert
      .dom(cell("/calm", "errors"))
      .hasText("0")
      .hasClass(
        "--zero",
        "a zero is absence of news, so it recedes instead of competing with the counts that matter"
      );
    assert
      .dom(cell("/quiet", "messages"))
      .hasText("0")
      .hasClass("--zero", "every numeric column dims the same way");
    assert
      .dom(cell("/boom", "errors"))
      .hasText("1")
      .hasClass("--danger", "a non-zero error count is the alarm in the table")
      .doesNotHaveClass("--zero");
    assert
      .dom(cell("/calm", "subscribers"))
      .hasText("1")
      .doesNotHaveClass("--zero");
    assert
      .dom(cell("/calm", "messages"))
      .hasText("1")
      .doesNotHaveClass("--zero");
  });

  test("a channel row flashes when a message lands on it", async function (assert) {
    this.bus.subscribe("/alpha", () => {});
    deliver("/alpha", {}, 1700, 1);

    await renderPanel();

    assert.dom(ROW).exists({ count: 1 });
    assert
      .dom(`${ROW}[data-test-was-highlighted]`)
      .doesNotExist(
        "history captured before the panel opened is not replayed as activity"
      );

    deliver("/alpha", {}, 1701, 2);
    await settled();

    assert
      .dom(`${ROW}[data-test-was-highlighted]`)
      .exists(
        { count: 1 },
        "a message arriving while the panel is open flashes the row it landed on"
      );
  });

  test("the channel table leads with the most recent traffic until told otherwise", async function (assert) {
    const base = Date.now();

    this.bus.subscribe("/a", () => {});
    this.bus.subscribe("/b", () => {});
    this.bus.subscribe("/c", () => {});
    this.bus.subscribe("/d", () => {});
    deliverAt(base - 30_000, "/d", {}, 4000, 1);
    deliverAt(base - 1000, "/b", {}, 4001, 1);

    await renderPanel();

    assert.deepEqual(
      channelNames(),
      ["/b", "/d", "/a", "/c"],
      // A panel is opened because something is happening now, not to read an
      // index of every channel the page ever subscribed to.
      "the channels that spoke most recently lead, and the silent ones fall back to their names"
    );
    assert
      .dom("th.dev-tools-message-bus__column.--last-message")
      .hasAttribute("aria-sort", "descending")
      .hasClass("is-current-sort");
    assert
      .dom("th.dev-tools-message-bus__column.--channel")
      .hasAttribute("aria-sort", "none");
    assert
      .dom(
        rowFor("/a").querySelector(
          ".dev-tools-message-bus__cell.--last-message"
        )
      )
      .hasText("-", "a channel that has never spoken shows a quiet placeholder")
      .hasClass("--zero", "the placeholder is dimmed like the zero values");

    for (const column of COLUMNS) {
      assert
        .dom(`th.dev-tools-message-bus__column.--${column} button`)
        .exists(`the ${column} column can be sorted from its header`);
    }
  });

  test("the sorted column is marked, and every column keeps room for its direction", async function (assert) {
    this.bus.subscribe("/aaa", () => {});
    this.bus.subscribe("/bbb", () => {});

    await renderPanel();

    for (const column of COLUMNS) {
      const button = document.querySelector(
        `th.dev-tools-message-bus__column.--${column} button`
      );

      assert
        .dom(button?.querySelector(SORT_ICON) ?? null)
        .exists(
          `the ${column} header always carries a direction icon, so marking the sort never reflows the row`
        );
    }

    assert
      .dom("th.dev-tools-message-bus__column.is-current-sort")
      .exists({ count: 1 }, "exactly one column is the current sort");
    assert
      .dom("th.dev-tools-message-bus__column.--last-message")
      .hasClass("is-current-sort");
    assert
      .dom(
        "th.dev-tools-message-bus__column.--last-message button .d-icon-angle-down"
      )
      .exists("descending points down");

    await click("th.dev-tools-message-bus__column.--messages button");

    assert
      .dom("th.dev-tools-message-bus__column.--messages")
      .hasClass("is-current-sort");
    assert
      .dom("th.dev-tools-message-bus__column.--last-message")
      .doesNotHaveClass("is-current-sort");
    assert
      .dom("th.dev-tools-message-bus__column.is-current-sort")
      .exists({ count: 1 });
    assert
      .dom(
        "th.dev-tools-message-bus__column.--messages button .d-icon-angle-up"
      )
      .exists("ascending points up");

    await click("th.dev-tools-message-bus__column.--messages button");

    assert
      .dom(
        "th.dev-tools-message-bus__column.--messages button .d-icon-angle-down"
      )
      .exists("descending points down");
    assert
      .dom(
        "th.dev-tools-message-bus__column.--messages button .d-icon-angle-up"
      )
      .doesNotExist("a header shows one direction, not both at once");
  });

  test("clicking a column header sorts by it, and clicking again flips it", async function (assert) {
    this.bus.subscribe("/aaa", () => {});
    this.bus.subscribe("/bbb", () => {});
    this.bus.subscribe("/ccc", () => {});
    deliver("/aaa", {}, 400, 1);
    deliver("/bbb", {}, 401, 1);
    deliver("/bbb", {}, 402, 2);
    deliver("/bbb", {}, 403, 3);
    deliver("/ccc", {}, 404, 1);
    deliver("/ccc", {}, 405, 2);

    await renderPanel();
    await click("th.dev-tools-message-bus__column.--messages button");

    assert.deepEqual(channelNames(), ["/aaa", "/ccc", "/bbb"]);
    assert
      .dom("th.dev-tools-message-bus__column.--messages")
      .hasAttribute("aria-sort", "ascending");
    assert
      .dom("th.dev-tools-message-bus__column.--last-message")
      .hasAttribute("aria-sort", "none", "only one column sorts at a time");

    await click("th.dev-tools-message-bus__column.--messages button");

    assert.deepEqual(channelNames(), ["/bbb", "/ccc", "/aaa"]);
    assert
      .dom("th.dev-tools-message-bus__column.--messages")
      .hasAttribute("aria-sort", "descending");
  });

  test("the sort is remembered in the developer tools state", async function (assert) {
    this.bus.subscribe("/aaa", () => {});

    await renderPanel();
    await click("th.dev-tools-message-bus__column.--subscribers button");

    assert.deepEqual(devToolsState.getFlag(TOOL_ID, "sort"), {
      column: "subscribers",
      asc: true,
    });

    await click("th.dev-tools-message-bus__column.--subscribers button");

    assert.deepEqual(devToolsState.getFlag(TOOL_ID, "sort"), {
      column: "subscribers",
      asc: false,
    });
  });

  test("a remembered sort is applied on the next render", async function (assert) {
    devToolsState.setFlag(TOOL_ID, "sort", { column: "messages", asc: false });

    this.bus.subscribe("/aaa", () => {});
    this.bus.subscribe("/bbb", () => {});
    this.bus.subscribe("/ccc", () => {});
    deliver("/aaa", {}, 500, 1);
    deliver("/bbb", {}, 501, 1);
    deliver("/bbb", {}, 502, 2);
    deliver("/bbb", {}, 503, 3);
    deliver("/ccc", {}, 504, 1);
    deliver("/ccc", {}, 505, 2);

    await renderPanel();

    assert.deepEqual(channelNames(), ["/bbb", "/ccc", "/aaa"]);
    assert
      .dom("th.dev-tools-message-bus__column.--messages")
      .hasAttribute("aria-sort", "descending");
  });

  test("a channel that loses its last subscriber leaves the live table for its own section", async function (assert) {
    const base = Date.now();
    const gone = () => {};

    this.bus.subscribe("/live", () => {});
    this.bus.subscribe("/gone", gone);
    deliverAt(base - 45_000, "/gone", { a: 1 }, 9000, 1);
    deliverAt(base - 44_000, "/gone", { a: 2 }, 9001, 2);
    unsubscribeAt(base - 30_000, "/gone", gone);

    await renderPanel();

    assert.deepEqual(
      channelNames(),
      ["/live"],
      // A channel nothing listens to any more is a different question from a
      // channel that is live, and mixing the two makes a zero in the subscriber
      // column read as an alarm on every row that has simply finished.
      "the live table is what is still subscribed, and nothing else"
    );
    assert.dom(CLOSED_TABLE).exists();

    // Document order, so this reads the two sections the way the panel does.
    const tables = [
      ...document.querySelectorAll(`${LIVE_TABLE}, ${CLOSED_TABLE}`),
    ];

    assert.strictEqual(
      tables.length,
      2,
      "the closed channels are their own table rather than more rows in the live one"
    );
    assert.true(
      tables[0]?.matches(LIVE_TABLE),
      "what is still live leads, and what has closed follows it"
    );
    assert
      .dom(CLOSED_HEADING)
      .exists()
      .includesText(
        "1",
        "the heading says how many channels went quiet, so the section is readable while collapsed"
      );

    assert.deepEqual(channelNames(CLOSED_ROW), ["/gone"]);
    assert.dom(rowFor("/gone", CLOSED_ROW)).hasClass("--closed");
    assert
      .dom(cell("/gone", "messages", CLOSED_ROW))
      .hasText(
        "2",
        "the history it left behind is the reason the row is still worth showing"
      );
    assert.dom(cell("/gone", "last-message", CLOSED_ROW)).hasAnyText();
    assert
      .dom(cell("/gone", "closed-ago", CLOSED_ROW))
      .includesText("30", "the row says how long ago the last subscriber left");
    assert
      .dom(`${CLOSED_TABLE} th`)
      .exists(
        { count: 4 },
        "a closed channel has no subscribers and no callbacks to time, so those columns go away"
      );
  });

  test("closed channels are led by the one that went quiet most recently", async function (assert) {
    const base = Date.now();
    const early = () => {};
    const late = () => {};

    this.bus.subscribe("/aaa", early);
    this.bus.subscribe("/zzz", late);
    deliverAt(base - 5000, "/aaa", {}, 9100, 1);
    deliverAt(base - 50_000, "/zzz", {}, 9101, 1);
    unsubscribeAt(base - 30_000, "/aaa", early);
    unsubscribeAt(base - 1000, "/zzz", late);

    await renderPanel();

    assert.deepEqual(
      channelNames(CLOSED_ROW),
      ["/zzz", "/aaa"],
      // Neither the channel name nor the last message would order them this way
      // round: the section answers "what did I just lose?"
      "the closed section is ordered by when each channel closed"
    );
    assert
      .dom(`${CLOSED_TABLE} th button`)
      .doesNotExist(
        "the closed list has one meaningful order, so its headers are labels rather than controls"
      );
    assert.dom(`${CLOSED_TABLE} th[aria-sort]`).doesNotExist();
  });

  test("the filter narrows the channels and lets them back when cleared", async function (assert) {
    this.bus.subscribe("/alpha", () => {});
    this.bus.subscribe("/alpha/nested", () => {});
    this.bus.subscribe("/beta", () => {});

    await renderPanel();

    assert
      .dom(FILTER)
      .hasAttribute("placeholder", i18n(key("filter_placeholder")));

    await fillIn(FILTER, "ALP");
    assert.deepEqual(
      channelNames(),
      ["/alpha", "/alpha/nested"],
      "matching is a case-insensitive substring, not a prefix"
    );

    await fillIn(FILTER, "nothing-like-this");
    assert.dom(ROW).doesNotExist();
    assert
      .dom(".dev-tools-message-bus__empty")
      .hasText(
        i18n(key("no_matches")),
        "an active filter explains itself rather than claiming nothing has happened"
      );

    await fillIn(FILTER, "");
    assert.deepEqual(channelNames(), ["/alpha", "/alpha/nested", "/beta"]);
  });

  test("the filter narrows the closed channels alongside the live ones", async function (assert) {
    const gone = () => {};

    this.bus.subscribe("/alpha/live", () => {});
    this.bus.subscribe("/alpha/gone", gone);
    deliver("/alpha/gone", {}, 9200, 1);
    this.bus.unsubscribe("/alpha/gone", gone);
    this.bus.subscribe("/beta/live", () => {});

    await renderPanel();

    assert.deepEqual(channelNames(), ["/alpha/live", "/beta/live"]);
    assert.deepEqual(channelNames(CLOSED_ROW), ["/alpha/gone"]);

    await fillIn(FILTER, "ALPHA");

    assert.deepEqual(channelNames(), ["/alpha/live"]);
    assert.deepEqual(
      channelNames(CLOSED_ROW),
      ["/alpha/gone"],
      "one filter narrows both tables, because it is one question about one bus"
    );

    await fillIn(FILTER, "beta");

    assert.deepEqual(channelNames(), ["/beta/live"]);
    assert
      .dom(CLOSED_TABLE)
      .doesNotExist("a section with nothing left to show is not left standing");
    assert.dom(CLOSED_HEADING).doesNotExist();

    await fillIn(FILTER, "gone");

    assert.dom(ROW).doesNotExist();
    assert.deepEqual(channelNames(CLOSED_ROW), ["/alpha/gone"]);
  });

  test("an empty table says nothing has been seen yet", async function (assert) {
    await renderPanel();

    assert.dom(ROW).doesNotExist();
    assert
      .dom(".dev-tools-message-bus__empty")
      .hasText(i18n(key("no_channels")));
  });

  test("expanding a channel reveals its subscribers and its messages", async function (assert) {
    this.bus.subscribe("/alpha", () => {});
    this.bus.subscribe("/alpha", () => {});
    this.bus.subscribe("/beta", () => {});
    deliver("/alpha", { a: 1 }, 600, 1);
    deliver("/alpha", { a: 2 }, 601, 2);

    await renderPanel();

    assert
      .dom("button.dev-tools-message-bus__expand")
      .doesNotExist(
        "the whole row is the target, so it does not also carry a chevron to hit"
      );
    assert.dom(nameFor("/alpha")).hasAttribute("aria-expanded", "false");
    assert.dom(rowFor("/alpha")).doesNotHaveClass("--expanded");
    assert.dom(DETAIL_ROW).doesNotExist();

    await click(rowFor("/alpha"));

    assert.dom(nameFor("/alpha")).hasAttribute("aria-expanded", "true");
    assert.dom(rowFor("/alpha")).hasClass("--expanded");
    assert.dom(DETAIL_ROW).exists({ count: 1 });
    assert
      .dom(`${DETAIL_ROW} .dev-tools-message-bus__subscriber`)
      .exists(
        { count: 2 },
        "the aggregated row opens onto the subscriptions behind it"
      );
    assert.dom(`${DETAIL_ROW} ${MESSAGE}`).exists({ count: 2 });
    assert
      .dom(nameFor("/beta"))
      .hasAttribute(
        "aria-expanded",
        "false",
        "one row opening does not open the rest of the table"
      );
    assert.dom(rowFor("/beta")).doesNotHaveClass("--expanded");

    await click(rowFor("/alpha"));

    assert.dom(DETAIL_ROW).doesNotExist();
    assert.dom(nameFor("/alpha")).hasAttribute("aria-expanded", "false");
    assert.dom(rowFor("/alpha")).doesNotHaveClass("--expanded");
  });

  test("the channel name is the control a keyboard reaches, and one press is one toggle", async function (assert) {
    this.bus.subscribe("/alpha", () => {});

    await renderPanel();

    assert.dom(nameFor("/alpha")).hasText("/alpha");

    await click(nameFor("/alpha"));

    assert
      .dom(DETAIL_ROW)
      .exists(
        { count: 1 },
        "the press lands once rather than opening the row and closing it again on its way up"
      );
    assert.dom(nameFor("/alpha")).hasAttribute("aria-expanded", "true");
    assert.dom(rowFor("/alpha")).hasClass("--expanded");

    await click(nameFor("/alpha"));

    assert.dom(DETAIL_ROW).doesNotExist();
    assert.dom(nameFor("/alpha")).hasAttribute("aria-expanded", "false");
    assert.dom(rowFor("/alpha")).doesNotHaveClass("--expanded");
  });

  test("the detail messages heading says how many were captured", async function (assert) {
    this.bus.subscribe("/alpha", () => {});
    deliver("/alpha", { a: 1 }, 1400, 1);
    deliver("/alpha", { a: 2 }, 1401, 2);
    deliver("/alpha", { a: 3 }, 1402, 3);

    await renderPanel();
    await click(rowFor("/alpha"));

    const headings = document.querySelectorAll(
      `${DETAIL_ROW} .dev-tools-message-bus__detail-heading`
    );

    assert.dom(headings[headings.length - 1]).hasText(
      i18n(key("messages_heading"), { count: 3 }),
      // A bare "Messages" leaves the reader counting list items to learn
      // whether the retention cap has already thrown history away.
      "the heading carries the count rather than making the list be counted"
    );
  });

  test("a subscriber reports where it was subscribed, or says it is unknown", async function (assert) {
    uninstall();
    this.bus.callbacks.push({
      channel: "/legacy",
      func: () => {},
      last_id: -1,
    });
    install();
    this.bus.subscribe("/known", () => {});
    deliver("/known", {}, 1200, 1);

    await renderPanel();
    await click(rowFor("/legacy"));

    assert
      .dom(`${DETAIL_ROW} .dev-tools-message-bus__source`)
      .hasText(
        i18n(key("source_unknown")),
        "a subscription made before dev tools loaded has no captured frame"
      );

    await click(rowFor("/legacy"));
    await click(rowFor("/known"));

    const source = document.querySelector(
      `${DETAIL_ROW} .dev-tools-message-bus__source`
    ).textContent;

    assert.notStrictEqual(source.trim(), i18n(key("source_unknown")));
    assert.false(
      source.includes("http://"),
      "the captured frame is shortened for a panel this narrow"
    );
    assert
      .dom(`${DETAIL_ROW} .dev-tools-message-bus__subscribed`)
      .hasAnyText("how long it has been subscribed is shown alongside");
    assert
      .dom(`${DETAIL_ROW} .dev-tools-message-bus__stats`)
      .includesText("1", "so are the calls and errors it has accumulated");
  });

  test("a subscriber can be logged to the console for source navigation", async function (assert) {
    this.bus.subscribe("/alpha", () => {});

    await renderPanel();
    await click(rowFor("/alpha"));

    const logged = [];
    /* eslint-disable no-console */
    const originalLog = console.log;
    console.log = (...args) => logged.push(args);

    try {
      await click(`${DETAIL_ROW} button.dev-tools-message-bus__log-source`);
    } finally {
      console.log = originalLog;
      /* eslint-enable no-console */
    }

    assert.true(
      logged
        .flat()
        .some(
          (entry) => typeof entry === "string" && entry.includes("/alpha#0")
        ),
      "the button logs the subscription it belongs to, not merely the channel"
    );
  });

  test("a closed channel opens onto the subscribers it used to have", async function (assert) {
    const gone = () => {};

    this.bus.subscribe("/gone", gone);
    deliver("/gone", { a: 1 }, 9300, 1);
    this.bus.unsubscribe("/gone", gone);

    await renderPanel();

    assert
      .dom(nameFor("/gone", CLOSED_ROW))
      .hasAttribute("aria-expanded", "false");
    assert.dom(CLOSED_DETAIL_ROW).doesNotExist();

    await click(rowFor("/gone", CLOSED_ROW));

    assert
      .dom(nameFor("/gone", CLOSED_ROW))
      .hasAttribute("aria-expanded", "true");
    assert.dom(rowFor("/gone", CLOSED_ROW)).hasClass("--expanded");
    assert.dom(CLOSED_DETAIL_ROW).exists({ count: 1 });
    assert
      .dom(`${CLOSED_DETAIL_ROW} .dev-tools-message-bus__empty`)
      .doesNotExist(
        // "No active subscribers" is true and useless here: the panel is open
        // precisely to find out which subscriber went away and where from.
        "a channel that had subscribers does not report having had none"
      );
    assert.dom(`${CLOSED_DETAIL_ROW} ${PAST_SUBSCRIBER}`).exists({ count: 1 });
    assert
      .dom(
        `${CLOSED_DETAIL_ROW} ${PAST_SUBSCRIBER} .dev-tools-message-bus__source`
      )
      .hasAnyText()
      .doesNotIncludeText(
        i18n(key("source_unknown")),
        "where a subscription was made outlives the subscription"
      );
    assert
      .dom(
        `${CLOSED_DETAIL_ROW} ${PAST_SUBSCRIBER} .dev-tools-message-bus__lifetime`
      )
      .hasAnyText(
        "how long it lived is the question a removed subscriber answers"
      );
    assert
      .dom(`${CLOSED_DETAIL_ROW} ${MESSAGE}`)
      .exists({ count: 1 }, "its captured messages read as they always did");

    await click(rowFor("/gone", CLOSED_ROW));

    assert.dom(CLOSED_DETAIL_ROW).doesNotExist();
  });

  test("a channel keeps its history across an unsubscribe and back", async function (assert) {
    const handler = () => {};

    this.bus.subscribe("/roundtrip", handler);
    deliver("/roundtrip", { a: 1 }, 9400, 1);

    await renderPanel();

    assert.deepEqual(channelNames(), ["/roundtrip"]);
    assert.dom(cell("/roundtrip", "messages")).hasText("1");
    assert.dom(CLOSED_TABLE).doesNotExist();

    this.bus.unsubscribe("/roundtrip", handler);
    await refreshPanel();

    assert.deepEqual(
      channelNames(),
      [],
      "the row leaves the live table the moment nothing is listening"
    );
    assert.deepEqual(channelNames(CLOSED_ROW), ["/roundtrip"]);
    assert
      .dom(cell("/roundtrip", "messages", CLOSED_ROW))
      .hasText(
        "1",
        "what it captured is not thrown away with the subscription"
      );
    assert.dom(cell("/roundtrip", "closed-ago", CLOSED_ROW)).hasAnyText();

    this.bus.subscribe("/roundtrip", handler);
    await refreshPanel();

    assert.deepEqual(
      channelNames(),
      ["/roundtrip"],
      "subscribing again returns the channel to the live table"
    );
    assert.dom(cell("/roundtrip", "subscribers")).hasText("1");
    assert.dom(cell("/roundtrip", "messages")).hasText(
      "1",
      // The panel is opened to watch a channel come and go; a count that
      // restarts each time hides exactly the churn being looked for.
      "the capture carries across the round trip, and only the closed stamp resets"
    );
    assert
      .dom(CLOSED_TABLE)
      .doesNotExist("the section goes away with its last closed row");
  });

  test("the stream view lists every message newest first, with its channel", async function (assert) {
    this.bus.subscribe("/alpha", () => {});
    this.bus.subscribe("/beta", () => {});
    deliver("/alpha", { a: 1 }, 700, 11);
    deliver("/beta", { b: 2 }, 701, 12);

    await renderPanel();

    assert.dom(CHANNELS_TAB).hasClass("active");
    assert.dom(STREAM_TAB).doesNotHaveClass("active");

    await click(STREAM_TAB);

    assert.dom(STREAM_TAB).hasClass("active");
    assert.dom(CHANNELS_TAB).doesNotHaveClass("active");
    assert
      .dom("table.dev-tools-message-bus__channels")
      .doesNotExist("the two views replace one another");

    assert.dom(STREAM_MESSAGE).exists({ count: 2 });
    assert.deepEqual(
      textsOf(
        ".dev-tools-message-bus__stream .dev-tools-message-bus__message-channel"
      ),
      ["/beta", "/alpha"],
      "the newest message is at the top and names its channel"
    );
    assert.deepEqual(
      textsOf(
        ".dev-tools-message-bus__stream .dev-tools-message-bus__message-id"
      ),
      ["#12", "#11"],
      "an id reads as an id rather than as an unexplained number"
    );
    assert
      .dom(`${STREAM_MESSAGE} .dev-tools-message-bus__message-time`)
      .hasAnyText("each message carries how long ago it arrived");
  });

  test("a message says what it is before it is opened", async function (assert) {
    const payload = { marker: "unique-marker-123" };

    devToolsState.setFlag(TOOL_ID, "view", "stream");
    this.bus.subscribe("/alpha", () => {});
    deliver("/alpha", payload, 1500, 31);

    await renderPanel();

    const message = document.querySelector(STREAM_MESSAGE);
    const id = message.querySelector(".dev-tools-message-bus__message-id");
    const size = message.querySelector(".dev-tools-message-bus__message-size");
    const preview = message.querySelector(
      ".dev-tools-message-bus__message-preview"
    );

    assert
      .dom(id)
      .hasText("#31")
      .hasAttribute("title")
      .doesNotHaveClass(
        "dev-tools-message-bus__chip",
        // Every row carries an id and a size, so badging them makes the whole
        // list read as an alert and leaves nothing to actually stand out.
        "an id present on every row is metadata rather than something to badge"
      )
      .doesNotHaveClass("--data");

    assert
      .dom(size)
      .hasAnyText()
      .hasAttribute("title")
      .doesNotHaveClass("dev-tools-message-bus__chip")
      .doesNotHaveClass("--data");

    assert
      .dom(preview)
      .includesText(
        "unique-marker-123",
        "the payload is legible without opening every row"
      );
    assert.false(
      (preview?.textContent.trim() ?? "\n").includes("\n"),
      "a message occupies one line, so a stream stays scannable"
    );

    assert
      .dom(message.querySelector(".dev-tools-message-bus__message-time"))
      .hasAnyText()
      .hasAttribute("title", /./, "the age resolves to an exact time on hover");
  });

  test("the stream holds back older messages until they are asked for", async function (assert) {
    devToolsState.setFlag(TOOL_ID, "view", "stream");
    this.bus.subscribe("/bulk", () => {});

    for (let index = 0; index < 105; index++) {
      deliver("/bulk", { index }, 1600 + index, index + 1);
    }

    await renderPanel();

    assert
      .dom(STREAM_MESSAGE)
      .exists(
        { count: 100 },
        "a busy bus does not get to render an unbounded list"
      );
    assert.dom(SHOW_OLDER).exists();

    await click(SHOW_OLDER);

    assert.dom(STREAM_MESSAGE).exists({ count: 105 });
    assert
      .dom(SHOW_OLDER)
      .doesNotExist("nothing is left to reveal, so the control goes away");
  });

  test("an empty stream says so", async function (assert) {
    devToolsState.setFlag(TOOL_ID, "view", "stream");

    await renderPanel();

    assert.dom(MESSAGE).doesNotExist();
    assert
      .dom(".dev-tools-message-bus__stream .dev-tools-message-bus__empty")
      .hasText(i18n(key("no_messages")));
  });

  test("the active view is remembered in the developer tools state", async function (assert) {
    await renderPanel();
    await click(STREAM_TAB);

    assert.strictEqual(devToolsState.getFlag(TOOL_ID, "view"), "stream");

    await click(CHANNELS_TAB);

    assert.strictEqual(devToolsState.getFlag(TOOL_ID, "view"), "channels");
  });

  test("a message payload stays collapsed until it is asked for", async function (assert) {
    const payload = { hello: "world", nested: { count: 2 } };

    devToolsState.setFlag(TOOL_ID, "view", "stream");
    this.bus.subscribe("/alpha", () => {});
    deliver("/alpha", payload, 800, 21);

    await renderPanel();

    assert.dom(PAYLOAD).doesNotExist();
    assert.dom(COPY_PAYLOAD).doesNotExist();

    const toggle = document.querySelector(
      `${MESSAGE} button.dev-tools-message-bus__message-toggle`
    );
    assert.dom(toggle).hasAttribute("aria-expanded", "false");

    await click(toggle);

    assert.dom(toggle).hasAttribute("aria-expanded", "true");
    assert
      .dom(PAYLOAD)
      .hasClass(
        "lang-json",
        "the payload goes through the shared highlighter rather than a bare pre"
      );
    assert.strictEqual(
      document.querySelector(PAYLOAD)?.textContent.trim(),
      JSON.stringify(payload, null, 2),
      "the payload is shown pretty printed"
    );

    assert
      .dom(COPY_PAYLOAD)
      .exists(
        // Selecting pretty-printed JSON out of a panel this narrow is a
        // drag-and-scroll exercise nobody should have to do by hand.
        "a payload worth reading is a payload worth taking elsewhere"
      )
      .hasAttribute("aria-label", /\S/)
      .hasAttribute("title", /\S/);

    await click(toggle);

    assert.dom(PAYLOAD).doesNotExist();
    assert.dom(COPY_PAYLOAD).doesNotExist();
  });

  test("a component may subscribe and unsubscribe while the panel renders", async function (assert) {
    const handler = () => {};

    // Components all over the app subscribe in their constructors, which run
    // inside a render pass. If observing a (re)subscription writes tracked
    // state the panel read earlier in that same pass, Glimmer's backtracking
    // assertion tears the whole render down.
    class MidRenderChurn extends Component {
      constructor(owner, args) {
        super(owner, args);
        window.MessageBus.subscribe("/mid-render", handler);
        window.MessageBus.unsubscribe("/mid-render", handler);
        window.MessageBus.subscribe("/mid-render", handler);
      }

      <template></template>
    }

    registerDockPanel(TOOL_ID, {
      label: "MessageBus",
      component: MessageBusPanel,
    });
    activateDockTool(TOOL_ID);

    await render(
      <template>
        <DevToolsDockHost />
        <MidRenderChurn />
      </template>
    );

    assert
      .dom(PANEL)
      .exists("subscription churn inside a render pass leaves the panel alive");
  });

  test("a message opens wherever it is clicked, except on the payload itself", async function (assert) {
    devToolsState.setFlag(TOOL_ID, "view", "stream");
    this.bus.subscribe("/alpha", () => {});
    deliver("/alpha", { hello: "world" }, 1550, 41);

    await renderPanel();

    const toggle = `${MESSAGE} button.dev-tools-message-bus__message-toggle`;
    const preview = `${MESSAGE} .dev-tools-message-bus__message-preview`;

    assert.dom(PAYLOAD).doesNotExist();

    await click(preview);

    assert
      .dom(PAYLOAD)
      .exists(
        "the whole row is the target, the same way a channel row is above it"
      );
    assert
      .dom(toggle)
      .hasAttribute(
        "aria-expanded",
        "true",
        "the chevron still reports the state, whichever part of the row set it"
      );

    await click(PAYLOAD);

    assert.dom(PAYLOAD).exists(
      // Reading and copying the JSON means clicking inside it, and a payload
      // that closes under the pointer cannot be selected at all.
      "a click meant for the payload is not a click on the row"
    );
    assert.dom(COPY_PAYLOAD).exists();

    await click(preview);

    assert.dom(PAYLOAD).doesNotExist("clicking the row again closes it");

    await click(toggle);

    assert
      .dom(PAYLOAD)
      .exists(
        { count: 1 },
        "the press lands once rather than opening the payload and closing it again on its way up"
      );

    await click(toggle);

    assert.dom(PAYLOAD).doesNotExist();
  });

  test("pausing stops recording without touching delivery", async function (assert) {
    let delivered = 0;

    this.bus.subscribe("/alpha", () => delivered++);
    deliver("/alpha", {}, 900, 1);

    await renderPanel();

    assert.dom(cell("/alpha", "messages")).hasText("1");

    await click("button.dev-tools-message-bus__pause");

    assert
      .dom("button.dev-tools-message-bus__pause")
      .hasAttribute("aria-pressed", "true")
      .hasAttribute("title", i18n(key("resume")));
    assert
      .dom(LIVE_DOT)
      .hasClass("--paused")
      .hasAttribute("title", i18n(key("paused")));

    deliver("/alpha", {}, 901, 2);
    await settled();

    assert.strictEqual(delivered, 2, "the subscriber still ran");
    assert
      .dom(cell("/alpha", "messages"))
      .hasText("1", "but nothing was recorded while paused");

    await click("button.dev-tools-message-bus__pause");

    assert
      .dom("button.dev-tools-message-bus__pause")
      .hasAttribute("aria-pressed", "false");
    assert.dom(LIVE_DOT).doesNotHaveClass("--paused");

    deliver("/alpha", {}, 902, 3);
    await settled();

    assert.dom(cell("/alpha", "messages")).hasText("2");
  });

  test("clearing asks before it drops what has been recorded", async function (assert) {
    this.bus.subscribe("/alpha", () => {});
    deliver("/alpha", {}, 1000, 1);
    deliver("/alpha", {}, 1001, 2);

    await renderPanelWithDialog();

    assert.dom(cell("/alpha", "messages")).hasText("2");
    assert
      .dom(`${ACTIONS} button.dev-tools-message-bus__clear .d-icon-ban`)
      .exists("clearing stops the capture rather than deleting a record");

    await click("button.dev-tools-message-bus__clear");

    assert.dom(".dialog-body").includesText(i18n(key("clear_confirm")));
    assert
      .dom(".dialog-footer .btn-danger")
      .exists("the irreversible choice is the marked one");
    assert.dom(".dialog-footer .btn-default").exists();
    assert
      .dom(cell("/alpha", "messages"))
      .hasText("2", "asking is not the same as doing");

    await click(".dialog-footer .btn-default");

    assert.dom(".dialog-body").doesNotExist();
    assert
      .dom(cell("/alpha", "messages"))
      .hasText("2", "backing out keeps a capture that cannot be recreated");

    await click("button.dev-tools-message-bus__clear");
    await click(".dialog-footer .btn-danger");

    assert
      .dom(cell("/alpha", "messages"))
      .hasText("0", "the channel is still subscribed, it just has no history");

    await click(STREAM_TAB);

    assert.dom(MESSAGE).doesNotExist();
    assert
      .dom(".dev-tools-message-bus__stream .dev-tools-message-bus__empty")
      .hasText(i18n(key("no_messages")));
  });

  test("the settings form writes the retention caps only once they are applied", async function (assert) {
    await renderPanel();

    assert.dom(CAP_CHANNEL).doesNotExist();

    await click(".dev-tools-message-bus__settings-trigger");

    assert
      .dom(`${MENU} form.form-kit`)
      .exists("the caps are a form, so a cap can be rejected before it lands");

    for (const [name, control] of Object.entries(CAP_FIELDS)) {
      assert.dom(fieldFor(name)).exists(`${name} is a form field`);
      assert.dom(`${MENU} ${control}`).exists().hasAttribute("type", "number");
    }

    assert
      .dom(MENU)
      .includesText(i18n(key("per_channel_cap")))
      .includesText(i18n(key("global_cap")))
      .includesText(i18n(key("tracked_channels_cap")));
    assert
      .dom(APPLY)
      .exists()
      .hasText(i18n(key("apply")));
    assert.dom(`${MENU} .dev-tools-message-bus__settings-reset`).exists();

    await fillIn(CAP_CHANNEL, "25");

    assert.strictEqual(
      devToolsState.getFlag(TOOL_ID, "maxChannelMessages"),
      undefined,
      "a half-typed cap does not get to truncate history mid-keystroke"
    );

    await fillIn(CAP_GLOBAL, "120");
    await fillIn(CAP_TRACKED, "400");
    await click(APPLY);

    assert.strictEqual(
      devToolsState.getFlag(TOOL_ID, "maxChannelMessages"),
      25,
      "the cap is stored as a number, which is what the instrumentation reads"
    );
    assert.strictEqual(
      devToolsState.getFlag(TOOL_ID, "maxGlobalMessages"),
      120
    );
    assert.strictEqual(
      devToolsState.getFlag(TOOL_ID, "maxTrackedChannels"),
      400
    );
  });

  test("a cap under its minimum is refused rather than stored", async function (assert) {
    await renderPanel();
    await click(".dev-tools-message-bus__settings-trigger");

    await fillIn(CAP_CHANNEL, "1");
    await click(APPLY);

    assert.strictEqual(
      devToolsState.getFlag(TOOL_ID, "maxChannelMessages"),
      undefined,
      "a cap the instrumentation would refuse is never written"
    );
    assert
      .dom(`${fieldFor("maxChannelMessages")} .form-kit__errors`)
      .exists("the field explains why it was refused");
  });

  test("dropped channels are reported, because the table is then incomplete", async function (assert) {
    await renderPanel();

    assert.dom(".dev-tools-message-bus__eviction-warning").doesNotExist();

    devToolsState.setFlag(TOOL_ID, "maxTrackedChannels", 50);
    deliverViaSuccess(
      Array.from({ length: 51 }, (_, index) =>
        frame(`/evict/${index}`, 1, 1100 + index, {})
      )
    );
    await settled();

    assert
      .dom(".dev-tools-message-bus__eviction-warning")
      .exists()
      .hasAttribute("role", "alert")
      .includesText(i18n(key("eviction_warning"), { count: 1 }));
  });
});
