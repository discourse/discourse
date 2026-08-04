import {
  trackedArray,
  trackedMap,
  trackedObject,
} from "@ember/reactive/collections";
import "message-bus-client";
import devToolsState from "discourse/static/dev-tools/state";

/**
 * Observation of MessageBus that the library does not expose on its own.
 *
 * The subscription list is already public: `MessageBus.callbacks` is the live
 * array, so channels, positions and subscription counts can simply be read.
 * What cannot be read is who registered a subscription, how long its callback
 * takes, whether it threw, and what arrived over a chunked response. Those
 * require standing between MessageBus and its callers, which is what this
 * module does while dev tools are loaded.
 *
 * Everything here is read-only with respect to MessageBus' behaviour: every
 * wrapper passes its arguments through untouched, returns what the original
 * returned, and rethrows what it threw.
 *
 * @module discourse/static/dev-tools/message-bus/instrumentation
 */

/**
 * A subscriber callback.
 *
 * MessageBus calls one with the message data plus the global and message ids,
 * but a subscriber is free to declare fewer parameters, and the wrappers below
 * relay whatever they were called with and return whatever came back.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
type MessageBusSubscriber = (...args: any[]) => unknown;

/** A subscription as MessageBus records it in its public `callbacks` array. */
interface MessageBusSubscription {
  channel: string;
  last_id: number;
  func: MessageBusSubscriber;
}

/** The request adapter MessageBus calls to run its long poll. */
type MessageBusAjax = (options: MessageBusAjaxOptions) => unknown;

/** The parts of a long poll request this module reads. */
interface MessageBusAjaxOptions {
  messageBus?: { chunked?: boolean };
  xhr?: () => XMLHttpRequest;
  success?: (...args: unknown[]) => unknown;
}

/** The parts of the MessageBus client this module stands in front of. */
interface MessageBusClient {
  callbacks: MessageBusSubscription[];
  subscribe: (
    channel: string,
    func: MessageBusSubscriber,
    lastId?: number
  ) => MessageBusSubscriber;
  unsubscribe: (channel: string, func?: MessageBusSubscriber) => boolean;
  ajax: MessageBusAjax;
  longPoll?: { abort: () => void } | null;
  status?: () => unknown;
  pause: () => void;
  resume: () => void;
}

// TODO(devxp-typescript-pending): `message-bus-client` ships no type
// declarations, so the global it installs is described here as the subset this
// module touches. Drop this once the package, or a core wrapper around it,
// provides its own types.
type MessageBusWindow = Window & { MessageBus?: MessageBusClient };

/** A message as it arrives in a response frame. */
interface MessageBusFrame {
  channel: string;
  message_id: number;
  global_id: number;
  data: unknown;
}

interface RecordableMessage {
  channel: string;
  messageId: number | null;
  globalId: number | null;
  data: unknown;
}

/**
 * A message this module has observed arriving.
 *
 * `data` is retained by reference for the hot path, so later payload mutation
 * is visible through captured history.
 */
export interface ObservedMessage {
  seq: number;
  channel: string;
  messageId: number | null;
  globalId: number | null;
  data: unknown;
  receivedAt: number;
}

interface ChannelRecord {
  channel: string;
  messages: ObservedMessage[];
  messageCount: number;
  lastMessageAt: number;
}

/** A snapshot of one removed subscription's lifetime and counters. */
export interface UnsubscribeEntry {
  seq: number;
  channel: string;
  source: string | null;
  subscribedAt: number | null;
  unsubscribedAt: number;
  calls: number;
  errors: number;
}

/** What is known about one subscription, accumulated as its callback runs. */
interface SubscriptionMeta {
  original: MessageBusSubscriber;
  channel: string;
  source: string | null;
  sourceError: Error | null;
  subscribedAt: number | null;
  lastCallAt: number | null;
  calls: number;
  errors: number;
  lastError: string | null;
  slowestMs: number;
}

/** The MessageBus methods replaced while installed, kept to restore them. */
interface ReplacedMethods {
  subscribe: MessageBusClient["subscribe"];
  unsubscribe: MessageBusClient["unsubscribe"];
  ajax: MessageBusAjax;
}

const TOOL_ID = "message-bus";
const MAX_UNSUBSCRIBES = 50;
const MAX_SEEN_GLOBAL_IDS = 1000;

/**
 * Per-subscription detail, keyed by the wrapper registered with MessageBus.
 *
 * Many-to-one on purpose. One function is routinely subscribed to several
 * channels — `topic-tracking-state` alone does it four times — so a wrapper
 * cannot be looked up from its original. Only this direction is well defined.
 */
const metaByWrapper = new WeakMap<MessageBusSubscriber, SubscriptionMeta>();

const channelRecords = trackedMap<string, ChannelRecord>();
const serverPositions = trackedMap<string, number>();
// Deliberately untracked: subscribe/unsubscribe run inside render passes
// (component constructors and teardown), where writing tracked state the
// panel already consumed trips Glimmer's backtracking assertion. The panel's
// refresh tick re-reads it, like the rest of the live bus state.
const closedAtByChannel = new Map<string, number>();
const unsubscribeLog = trackedArray<UnsubscribeEntry>([]);

const state = trackedObject({
  installed: false,
  messages: trackedArray<ObservedMessage>([]),
  polls: 0,
  paused: false,
  serverStatusAt: null as number | null,
  evictedChannelCount: 0,
});

let originals: ReplacedMethods | null = null;
let underlyingAjax: MessageBusAjax | null = null;
let nextSequence = 1;
let lastDirect: { channel: string; data: unknown } | null = null;
const seenGlobalIds = new Set<number>();

/**
 * Observed state, for the inspector to render.
 *
 * @returns The tracked state object.
 */
export function messageBusState() {
  return state;
}

/**
 * Describes what is currently subscribed, newest registrations last.
 *
 * Read straight from the live `MessageBus.callbacks` array, so it reflects
 * subscriptions made before dev tools loaded as well as after.
 *
 * @returns One entry per subscription.
 */
export function subscriptions() {
  const callbacks = (window as MessageBusWindow).MessageBus?.callbacks ?? [];
  const perChannel = new Map<string, number>();

  for (const callback of callbacks) {
    perChannel.set(
      callback.channel,
      (perChannel.get(callback.channel) ?? 0) + 1
    );
  }

  const seenPerChannel = new Map<string, number>();

  return callbacks.map((callback) => {
    const meta = metaByWrapper.get(callback.func);
    // A channel can legitimately hold several subscriptions, so the channel
    // alone does not identify one. Numbering them within their channel gives
    // each row a key that survives a refresh.
    const ordinal = seenPerChannel.get(callback.channel) ?? 0;
    seenPerChannel.set(callback.channel, ordinal + 1);

    return {
      id: `${callback.channel}#${ordinal}`,
      channel: callback.channel,
      lastId: callback.last_id,
      // A channel with more than one subscription is legal, but it is also
      // what an unbalanced subscribe looks like, so it is worth surfacing.
      duplicated: perChannel.get(callback.channel) > 1,
      source: meta?.source,
      subscribedAt: meta?.subscribedAt ?? null,
      lastCallAt: meta?.lastCallAt ?? null,
      calls: meta?.calls ?? 0,
      errors: meta?.errors ?? 0,
      lastError: meta?.lastError,
      slowestMs: meta?.slowestMs ?? 0,
    };
  });
}

/**
 * Starts observing MessageBus. Safe to call more than once.
 */
export function install() {
  const bus = (window as MessageBusWindow).MessageBus;

  if (state.installed || !bus) {
    return;
  }

  originals = {
    subscribe: bus.subscribe,
    unsubscribe: bus.unsubscribe,
    ajax: bus.ajax,
  };

  underlyingAjax = bus.ajax;

  bus.subscribe = instrumentedSubscribe;
  bus.unsubscribe = instrumentedUnsubscribe;

  // An accessor rather than an assignment. The MessageBus instance initializer
  // replaces `ajax` outright, and it runs after the dev tools chunk has loaded,
  // so a plain assignment here would simply be overwritten. Routing later
  // assignments into `underlyingAjax` keeps this wrapper outermost whichever
  // order the two run in.
  Object.defineProperty(bus, "ajax", {
    configurable: true,
    enumerable: true,
    get: () => instrumentedAjax,
    set: (implementation: MessageBusAjax) => {
      underlyingAjax = implementation;
    },
  });

  // Subscriptions made before dev tools loaded are wrapped where they sit, so
  // that they report like any other. Their source is unknown: the call that
  // created them has already returned.
  for (const callback of bus.callbacks) {
    callback.func = wrapCallback(
      callback.func,
      callback.channel,
      null,
      null,
      null
    );
  }

  state.installed = true;
}

/**
 * Stops observing MessageBus and restores what it replaced.
 */
export function uninstall() {
  const bus = (window as MessageBusWindow).MessageBus;

  if (state.installed && bus && originals) {
    bus.subscribe = originals.subscribe;
    bus.unsubscribe = originals.unsubscribe;

    // Replace the accessor with a plain value again, carrying whatever
    // implementation was most recently assigned to it.
    Object.defineProperty(bus, "ajax", {
      configurable: true,
      enumerable: true,
      writable: true,
      value: underlyingAjax,
    });

    for (const callback of bus.callbacks) {
      const meta = metaByWrapper.get(callback.func);

      if (meta) {
        callback.func = meta.original;
      }
    }
  }

  resetCaptured();
  state.paused = false;
  state.installed = false;
  originals = null;
  underlyingAjax = null;
}

/**
 * Wraps a subscriber so its calls can be counted and timed.
 *
 * @param original - The callback the caller passed to `subscribe`.
 * @param channel - The channel it was subscribed to.
 * @param source - Where it was subscribed from, if known.
 * @param sourceError - The captured stack, if the subscription was observed.
 * @param subscribedAt - When the subscription was observed.
 * @returns The wrapper to register in its place.
 */
function wrapCallback(
  original: MessageBusSubscriber,
  channel: string,
  source: string | null,
  sourceError: Error | null,
  subscribedAt: number | null
) {
  const wrapper = function (this: unknown) {
    const meta = metaByWrapper.get(wrapper);
    const recording = !state.paused;
    const startedAt = recording ? performance.now() : 0;

    if (recording) {
      meta.calls++;
      meta.lastCallAt = Date.now();

      // MessageBus invokes subscribers as `(data, globalId, messageId)`.
      // Missing ids identify direct test-helper delivery.
      recordMessage({
        channel,
        // eslint-disable-next-line prefer-rest-params
        data: arguments[0],
        // eslint-disable-next-line prefer-rest-params
        globalId: normalizeId(arguments[1]),
        // eslint-disable-next-line prefer-rest-params
        messageId: normalizeId(arguments[2]),
      });
    }

    try {
      // The return value matters: `publishToMessageBus` in the test helpers
      // awaits what subscribers return, so swallowing it would silently stop
      // tests waiting for asynchronous subscribers.
      // eslint-disable-next-line prefer-rest-params
      return original.apply(this, arguments);
    } catch (error) {
      if (recording) {
        meta.errors++;
        meta.lastError = error instanceof Error ? error.message : String(error);
      }

      // MessageBus logs subscriber exceptions itself, so this must still
      // propagate or that logging stops happening.
      throw error;
    } finally {
      if (recording) {
        meta.slowestMs = Math.max(
          meta.slowestMs,
          performance.now() - startedAt
        );
      }
    }
  };

  metaByWrapper.set(wrapper, {
    original,
    channel,
    source,
    sourceError,
    subscribedAt,
    lastCallAt: null,
    calls: 0,
    errors: 0,
    lastError: null,
    slowestMs: 0,
  });

  return wrapper;
}

function instrumentedSubscribe(
  this: unknown,
  channel: string,
  func: MessageBusSubscriber,
  lastId?: number
) {
  const captured = captureSource();
  const wrapper = wrapCallback(
    func,
    channel,
    captured.source,
    captured.error,
    Date.now()
  );

  originals.subscribe.call(this, channel, wrapper, lastId);
  closedAtByChannel.delete(channel);

  // `subscribe` returns the function it registered. Returning the original
  // instead keeps the wrapper invisible, so a caller that holds on to the
  // return value and unsubscribes with it still matches.
  return func;
}

/**
 * `unsubscribe`, reimplemented so that it matches on the original callback.
 *
 * MessageBus matches subscriptions by function identity, and no caller in
 * Discourse keeps the value `subscribe` returned — they all pass the same bound
 * method back. Delegating to the real implementation would therefore compare a
 * caller's function against the wrapper standing in for it, match nothing, and
 * leave the subscription in place. That would manufacture exactly the leaks
 * this tool exists to report.
 *
 * Translating the argument to "the" wrapper is not possible either, because one
 * function may be subscribed to many channels and so have many wrappers. Each
 * entry is therefore unwrapped and compared individually.
 *
 * The surrounding logic mirrors the original: trailing-`*` globbing, iterating
 * in reverse, removing every match rather than the first, and aborting the
 * in-flight long poll if anything was removed.
 */
function instrumentedUnsubscribe(channel: string, func?: MessageBusSubscriber) {
  const bus = (window as MessageBusWindow).MessageBus;
  const removedChannels = new Set<string>();
  let glob = false;

  if (channel.indexOf("*", channel.length - 1) !== -1) {
    channel = channel.substr(0, channel.length - 1);
    glob = true;
  }

  let removed = false;

  for (let i = bus.callbacks.length - 1; i >= 0; i--) {
    const callback = bus.callbacks[i];
    let keep;

    if (glob) {
      keep = callback.channel.substr(0, channel.length) !== channel;
    } else {
      keep = callback.channel !== channel;
    }

    const registered =
      metaByWrapper.get(callback.func)?.original ?? callback.func;

    if (!keep && func && registered !== func) {
      keep = true;
    }

    if (!keep) {
      const meta = metaByWrapper.get(callback.func);

      if (meta) {
        unsubscribeLog.push({
          seq: nextSequence++,
          channel: callback.channel,
          source: meta.source,
          subscribedAt: meta.subscribedAt,
          unsubscribedAt: Date.now(),
          calls: meta.calls,
          errors: meta.errors,
        });

        if (unsubscribeLog.length > MAX_UNSUBSCRIBES) {
          unsubscribeLog.splice(0, unsubscribeLog.length - MAX_UNSUBSCRIBES);
        }
      }

      bus.callbacks.splice(i, 1);
      removedChannels.add(callback.channel);
      removed = true;
    }
  }

  for (const removedChannel of removedChannels) {
    if (!bus.callbacks.some(({ channel: live }) => live === removedChannel)) {
      closedAtByChannel.set(removedChannel, Date.now());
    }
  }

  if (removed && bus.longPoll) {
    bus.longPoll.abort();
  }

  return removed;
}

function instrumentedAjax(this: unknown, options: MessageBusAjaxOptions) {
  if (typeof underlyingAjax !== "function") {
    // Preserve the error MessageBus raises when no adapter is present. The
    // accessor always returns a function, so its own guard can no longer fire.
    throw new Error("Either jQuery or the ajax adapter must be loaded");
  }

  if (!state.paused) {
    state.polls++;
  }

  // Called through as a method. MessageBus invokes `me.ajax(...)`, so an
  // adapter is entitled to read `this`; calling it bare would silently change
  // that to undefined.
  return underlyingAjax.call(this, decorateRequest(options));
}

/**
 * Adds recording hooks for both chunked and conventional responses.
 *
 * Chunked is the usual mode in development, and in that mode MessageBus'
 * `success` handler does nothing at all — messages are delivered through
 * `xhr.onprogress`. Reading only `success` would therefore observe nothing
 * locally.
 *
 * @param options - The options MessageBus passed to `ajax`.
 * @returns The options, decorated only where recording hooks are available.
 */
function decorateRequest(
  options: MessageBusAjaxOptions
): MessageBusAjaxOptions {
  const decorateXhr =
    options?.messageBus?.chunked && typeof options.xhr === "function";
  const decorateSuccess = typeof options?.success === "function";

  if (!decorateXhr && !decorateSuccess) {
    return options;
  }

  const originalXhr = options.xhr;
  const originalSuccess = options.success;

  return {
    ...options,
    ...(decorateXhr && {
      xhr(this: MessageBusAjaxOptions) {
        // jQuery invokes this as `options.xhr()`, and MessageBus' own factory
        // reads `this.messageBus`. Calling it any other way throws under strict
        // mode and takes down every poll, not just this tool.
        // eslint-disable-next-line prefer-rest-params
        const xhr = originalXhr.apply(this, arguments);
        let position = 0;

        // A listener rather than an assignment: MessageBus sets the `onprogress`
        // property, and the two coexist.
        xhr.addEventListener("progress", () => {
          position = readChunks(xhr.responseText, position);
        });

        return xhr;
      },
    }),
    ...(decorateSuccess && {
      success(this: unknown) {
        // Observe a parsed view but pass the untouched body, receiver,
        // arguments, and return value through to the client.
        // eslint-disable-next-line prefer-rest-params
        recordPayload(arguments[0]);
        // eslint-disable-next-line prefer-rest-params
        return originalSuccess.apply(this, arguments);
      },
    }),
  };
}

/**
 * Reads whole frames out of a chunked response body.
 *
 * MessageBus' own framing is private to its request, so it is reimplemented
 * here: frames are separated by `\r\n|\r\n`, and a literal separator inside a
 * frame is escaped by doubling the pipe.
 *
 * @param payload - The response body so far.
 * @param position - Where the last complete frame ended.
 * @returns The new cursor position.
 */
function readChunks(payload: string, position: number) {
  const separator = "\r\n|\r\n";

  for (;;) {
    const end = payload.indexOf(separator, position);

    if (end === -1) {
      return position;
    }

    const frame = payload
      .substring(position, end)
      .replace(/\r\n\|\|\r\n/g, separator);

    try {
      for (const message of JSON.parse(frame) as MessageBusFrame[]) {
        routeFrame(message);
      }
    } catch {
      // A frame that does not parse is MessageBus' problem to report; this is
      // only observing.
    }

    position = end + separator.length;
  }
}

function recordPayload(payload: unknown) {
  try {
    const messages =
      typeof payload === "string" ? JSON.parse(payload) : payload;

    if (Array.isArray(messages)) {
      for (const message of messages as MessageBusFrame[]) {
        routeFrame(message);
      }
    }
  } catch {
    // Parsing remains the MessageBus client's responsibility.
  }
}

function routeFrame(frame: MessageBusFrame) {
  if (frame.channel === "/__status") {
    recordStatus(frame.data);
    return;
  }

  recordMessage({
    channel: frame.channel,
    messageId: normalizeId(frame.message_id),
    globalId: normalizeId(frame.global_id),
    data: frame.data,
  });
}

function recordStatus(data: unknown) {
  if (state.paused || !data || typeof data !== "object") {
    return;
  }

  for (const [channel, position] of Object.entries(data)) {
    if (typeof position === "number") {
      serverPositions.set(channel, position);
    }
  }

  state.serverStatusAt = Date.now();
}

/**
 * Stores one arrival without cloning its data payload.
 *
 * Consumers must treat `data` as a snapshot by convention: later mutation of
 * the source object is visible here. Direct deliveries without global ids are
 * deduplicated only across synchronous sibling callback fan-out.
 */
function recordMessage(message: RecordableMessage) {
  if (state.paused || isDuplicate(message)) {
    return;
  }

  const receivedAt = Date.now();
  const observed: ObservedMessage = {
    seq: nextSequence++,
    channel: message.channel,
    messageId: message.messageId,
    globalId: message.globalId,
    data: message.data,
    receivedAt,
  };

  state.messages.push(observed);
  trimOldest(
    state.messages,
    configuredCap("maxGlobalMessages", 500, 10, 10_000)
  );

  let record = channelRecords.get(message.channel);

  if (!record) {
    record = trackedObject({
      channel: message.channel,
      messages: trackedArray<ObservedMessage>([]),
      messageCount: 0,
      lastMessageAt: receivedAt,
    });
    channelRecords.set(message.channel, record);
  }

  record.messages.push(observed);
  record.messageCount++;
  record.lastMessageAt = receivedAt;
  trimOldest(
    record.messages,
    configuredCap("maxChannelMessages", 50, 10, 2_000)
  );
  evictChannels();
}

function isDuplicate(message: RecordableMessage) {
  if (message.globalId !== null) {
    if (seenGlobalIds.has(message.globalId)) {
      return true;
    }

    seenGlobalIds.add(message.globalId);
    if (seenGlobalIds.size > MAX_SEEN_GLOBAL_IDS) {
      const oldest = seenGlobalIds.values().next().value;
      if (oldest !== undefined) {
        seenGlobalIds.delete(oldest);
      }
    }
    return false;
  }

  if (
    lastDirect?.channel === message.channel &&
    lastDirect.data === message.data
  ) {
    return true;
  }

  const marker = (lastDirect = {
    channel: message.channel,
    data: message.data,
  });
  queueMicrotask(() => {
    if (lastDirect === marker) {
      lastDirect = null;
    }
  });
  return false;
}

function normalizeId(value: unknown): number | null {
  return typeof value === "number" ? value : null;
}

function configuredCap(
  key: string,
  fallback: number,
  minimum: number,
  maximum: number
) {
  const configured = devToolsState.getFlag(TOOL_ID, key);
  const value =
    typeof configured === "number" && Number.isFinite(configured)
      ? configured
      : fallback;
  return Math.min(maximum, Math.max(minimum, Math.floor(value)));
}

function trimOldest<T>(items: T[], cap: number) {
  if (items.length > cap) {
    items.splice(0, items.length - cap);
  }
}

function evictChannels() {
  const cap = configuredCap("maxTrackedChannels", 300, 50, 2_000);
  const callbacks = (window as MessageBusWindow).MessageBus?.callbacks ?? [];
  const liveChannels = new Set(callbacks.map(({ channel }) => channel));

  while (channelRecords.size > cap) {
    const records = [...channelRecords.values()];
    const candidates = records.some(({ channel }) => !liveChannels.has(channel))
      ? records.filter(({ channel }) => !liveChannels.has(channel))
      : records;
    candidates.sort((left, right) => left.lastMessageAt - right.lastMessageAt);
    channelRecords.delete(candidates[0].channel);
    state.evictedChannelCount++;
  }
}

/**
 * Captures where `subscribe` was called from.
 *
 * @returns A single stack frame, or null if unavailable.
 */
function captureSource() {
  const error = new Error();
  const lines = error.stack?.split("\n") ?? [];

  // Frame 0 is the Error, 1 is this function, 2 is instrumentedSubscribe, so
  // the caller is the first frame after those.
  return { source: lines[3]?.trim() ?? null, error };
}

/**
 * Aggregates live subscriptions, recorded traffic, server positions, and
 * observed channel closures by channel.
 *
 * @returns Stable channel-sorted summary rows.
 */
export function channelSummaries() {
  if (!state.installed) {
    return [];
  }

  const subscriberRows = subscriptions();
  const channels = new Set([
    ...subscriberRows.map(({ channel }) => channel),
    ...channelRecords.keys(),
    ...serverPositions.keys(),
    ...closedAtByChannel.keys(),
  ]);

  return [...channels].sort().map((channel) => {
    const subscribers = subscriberRows.filter(
      (subscriber) => subscriber.channel === channel
    );
    const record = channelRecords.get(channel);
    const localPosition = subscribers.length
      ? Math.max(...subscribers.map(({ lastId }) => lastId))
      : null;
    const serverPosition = serverPositions.get(channel) ?? null;

    return {
      channel,
      subscriberCount: subscribers.length,
      duplicated: subscribers.length > 1,
      localPosition,
      serverPosition,
      lag:
        localPosition !== null && serverPosition !== null
          ? serverPosition - localPosition
          : null,
      messageCount: record?.messageCount ?? 0,
      lastMessageAt: record?.lastMessageAt ?? null,
      calls: subscribers.reduce((total, row) => total + row.calls, 0),
      errors: subscribers.reduce((total, row) => total + row.errors, 0),
      slowestMs: subscribers.reduce(
        (slowest, row) => Math.max(slowest, row.slowestMs),
        0
      ),
      closedAt: subscribers.length
        ? null
        : (closedAtByChannel.get(channel) ?? null),
    };
  });
}

/**
 * Reads one channel's subscribers and retained message history.
 *
 * @param channel - The exact MessageBus channel.
 * @returns Channel detail, or null when it has neither subscribers nor a
 * retained record.
 */
export function channelDetail(channel: string) {
  if (!state.installed) {
    return null;
  }

  const subscribers = subscriptions().filter((row) => row.channel === channel);
  const record = channelRecords.get(channel);
  const serverPosition = serverPositions.get(channel);
  const closedAt = closedAtByChannel.get(channel);

  if (
    !subscribers.length &&
    !record &&
    serverPosition === undefined &&
    closedAt === undefined
  ) {
    return null;
  }

  return {
    channel,
    subscribers,
    pastSubscribers: recentUnsubscribes().filter(
      (entry) => entry.channel === channel
    ),
    messages: record ? [...record.messages].reverse() : [],
    messageCount: record?.messageCount ?? 0,
    serverPosition: serverPosition ?? null,
  };
}

/**
 * Reads the retained global stream without exposing its mutable tracked array.
 * Message payloads remain shared references to the values MessageBus supplied.
 *
 * @returns A newest-first snapshot.
 */
export function globalMessages() {
  return [...state.messages].reverse();
}

/**
 * Reads recently removed subscriptions.
 *
 * @returns A newest-first snapshot, capped at 50 entries.
 */
export function recentUnsubscribes() {
  return [...unsubscribeLog].reverse();
}

/**
 * Reads top-level instrumentation and live MessageBus counters.
 *
 * @returns Current aggregate state.
 */
export function summary() {
  const bus = (window as MessageBusWindow).MessageBus;
  const channels = channelSummaries();

  return {
    subscriptionCount: state.installed ? (bus?.callbacks.length ?? 0) : 0,
    channelCount: channels.length,
    duplicatedChannelCount: channels.filter(({ duplicated }) => duplicated)
      .length,
    polls: state.polls,
    busStatus: readBusStatus(bus),
    capturePaused: state.paused,
    serverStatusAt: state.serverStatusAt,
    evictedChannelCount: state.evictedChannelCount,
  };
}

function readBusStatus(bus: MessageBusClient | undefined): unknown {
  try {
    return typeof bus?.status === "function" ? bus.status() : null;
  } catch {
    return null;
  }
}

/**
 * Pauses or resumes instrumentation recording without affecting MessageBus.
 *
 * @param paused - Whether observation writes should be suppressed.
 */
export function setCapturePaused(paused: boolean) {
  state.paused = paused;
}

/**
 * Clears retained observations while preserving subscription origins and
 * lifetimes. Sequence numbers remain monotonic across clears.
 */
export function clearCaptured() {
  resetCaptured();

  const callbacks = (window as MessageBusWindow).MessageBus?.callbacks ?? [];
  for (const callback of callbacks) {
    const meta = metaByWrapper.get(callback.func);

    if (meta) {
      meta.calls = 0;
      meta.errors = 0;
      meta.lastError = null;
      meta.slowestMs = 0;
      meta.lastCallAt = null;
    }
  }
}

function resetCaptured() {
  state.messages.length = 0;
  channelRecords.clear();
  serverPositions.clear();
  closedAtByChannel.clear();
  unsubscribeLog.length = 0;
  state.polls = 0;
  state.serverStatusAt = null;
  state.evictedChannelCount = 0;
  seenGlobalIds.clear();
  lastDirect = null;
}

/**
 * Pauses or resumes the real MessageBus transport.
 *
 * @param paused - Whether MessageBus itself should be paused.
 */
export function setBusPaused(paused: boolean) {
  const bus = (window as MessageBusWindow).MessageBus;

  if (!bus) {
    return;
  }

  if (paused) {
    bus.pause();
  } else {
    bus.resume();
  }
}

/**
 * Logs a subscription's captured stack and original callback for browser
 * source navigation.
 *
 * @param subscriptionId - The id returned by {@link subscriptions}.
 */
export function logSubscriberToConsole(subscriptionId: string) {
  const bus = (window as MessageBusWindow).MessageBus;
  const rows = subscriptions();
  const index = rows.findIndex(({ id }) => id === subscriptionId);

  /* eslint-disable no-console */
  if (!bus || index === -1) {
    console.log(
      `[MessageBus dev tools] No subscriber matches ${subscriptionId}.`
    );
    return;
  }

  const callback = bus.callbacks[index];
  const meta = metaByWrapper.get(callback.func);

  if (!meta) {
    console.log(
      `[MessageBus dev tools] No captured metadata exists for ${subscriptionId}.`
    );
  } else if (!meta.sourceError) {
    console.log(
      `[MessageBus dev tools] ${subscriptionId} predates instrumentation; its subscription stack is unavailable.`,
      meta.original
    );
  } else {
    console.log(
      `[MessageBus dev tools] Subscriber ${subscriptionId}`,
      meta.sourceError,
      meta.original
    );
  }
  /* eslint-enable no-console */
}
