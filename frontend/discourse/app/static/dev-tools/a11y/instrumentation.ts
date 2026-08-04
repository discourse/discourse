import { trackedArray } from "@ember/reactive/collections";
import { next } from "@ember/runloop";
import A11y from "discourse/services/a11y";
import {
  classifyCursor,
  composeUtterance,
  type Containment,
  type CursorInfo,
  describeBarriers,
  describeContainment,
} from "discourse/static/dev-tools/a11y/inspect";
import devToolsState from "discourse/static/dev-tools/state";

export type EntryKind = "event" | "intent" | "spoken" | "meta";

export interface A11ySnapshot {
  focused: Element | null;
  cursor: CursorInfo;
  barriers: string[];
  containment: Containment;
  utterance?: string;
}

export interface TimelineEntry {
  seq: number;
  kind: EntryKind;
  label: string;
  detail: string;
  snapshot?: A11ySnapshot;
}

export const TIMELINE_LIMIT = 200;

const TOOL_ID = "a11y";
// The dev-tools chrome and anything carrying the opt-out marker never enter
// the trace they help produce.
const TOOLBAR_SELECTOR = ".dev-tools-toolbar, [data-dev-tools-trace-exclude]";
const CORE_LIVE_REGION_SELECTORS = [
  "#a11y-announcements-polite",
  "#a11y-announcements-assertive",
] as const;
const CAPTURE_EVENT_TYPES = ["focusin", "keyup", "click"] as const;

type Announce = typeof A11y.prototype.announce;

const timeline = trackedArray<TimelineEntry>();
let sequence = 0;
let paused = devToolsState.getFlag(TOOL_ID, "paused") === true;
let consoleMirror = devToolsState.getFlag(TOOL_ID, "consoleMirror") === true;
let originalAnnounce: Announce | undefined;
let liveRegionObservers: MutationObserver[] = [];
let captureDocument: Document | undefined;
let captureGeneration = 0;

function record(
  kind: EntryKind,
  label: string,
  detail: string,
  snapshot?: A11ySnapshot
): void {
  if (paused) {
    return;
  }

  const entry: TimelineEntry = {
    seq: ++sequence,
    kind,
    label,
    detail,
    ...(snapshot ? { snapshot } : {}),
  };

  timeline.push(entry);
  if (timeline.length > TIMELINE_LIMIT) {
    timeline.splice(0, timeline.length - TIMELINE_LIMIT);
  }

  if (consoleMirror) {
    // eslint-disable-next-line no-console
    console.log(`[a11y] #${entry.seq} ${entry.label} ${entry.detail}`);
  }
}

function describeArgument(value: unknown): string {
  if (typeof value === "string") {
    return value;
  }

  return typeof value;
}

function recordIntent(args: Parameters<Announce>): void {
  if (paused) {
    return;
  }

  const [message, politeness = "polite"] = args;
  record(
    "intent",
    "announce intent",
    `message=${describeArgument(message)} politeness=${describeArgument(politeness)}`
  );
}

function recordSpoken(region: Element, text: string): boolean {
  if (paused) {
    return false;
  }

  record(
    "spoken",
    "live region spoken",
    `region=${region.id || region.getAttribute("aria-live") || "anonymous"} text=${text}`
  );
  return true;
}

function recordMeta(label: string, detail: string): void {
  if (paused) {
    return;
  }

  record("meta", label, detail);
}

function isToolbarElement(element: Element): boolean {
  return Boolean(element.closest(TOOLBAR_SELECTOR));
}

function liveRegions(doc: Document): Element[] {
  const regions = new Set<Element>();

  for (const selector of CORE_LIVE_REGION_SELECTORS) {
    const region = doc.querySelector(selector);
    if (region) {
      regions.add(region);
    }
  }

  for (const region of doc.querySelectorAll("[aria-live]")) {
    regions.add(region);
  }

  return [...regions].filter((region) => !isToolbarElement(region));
}

function eventStartsInToolbar(event: Event, doc: Document): boolean {
  const ElementConstructor = doc.defaultView?.Element;
  if (!ElementConstructor) {
    return false;
  }

  return event
    .composedPath()
    .some(
      (target) =>
        target instanceof ElementConstructor && isToolbarElement(target)
    );
}

function snapshotFor(doc: Document): A11ySnapshot {
  const focused = doc.activeElement;
  const cursor = classifyCursor(focused);

  return {
    focused,
    cursor,
    barriers: focused ? describeBarriers(focused) : [],
    containment: describeContainment(focused, cursor.target),
    ...(cursor.target ? { utterance: composeUtterance(cursor.target) } : {}),
  };
}

function captureEvent(event: Event): void {
  const doc = event.currentTarget;
  if (!(doc instanceof Document) || eventStartsInToolbar(event, doc)) {
    return;
  }

  const eventType = event.type;
  const generation = captureGeneration;
  next(() => {
    if (generation !== captureGeneration || captureDocument !== doc) {
      return;
    }

    const snapshot = snapshotFor(doc);
    record(
      "event",
      `${eventType} event`,
      `active=${snapshot.focused?.id || snapshot.focused?.tagName.toLowerCase() || "none"}`,
      snapshot
    );
  });
}

/** Installs the announcement-intent tap once. */
export function installA11yTap(): void {
  if (originalAnnounce) {
    return;
  }

  originalAnnounce = A11y.prototype.announce;
  A11y.prototype.announce = function (
    this: A11y,
    ...args: Parameters<Announce>
  ): ReturnType<Announce> {
    recordIntent(args);
    return Reflect.apply(originalAnnounce!, this, args) as ReturnType<Announce>;
  };
}

/** Removes the announcement tap and restores the original method identity. */
export function uninstallA11yTap(): void {
  if (!originalAnnounce) {
    return;
  }

  A11y.prototype.announce = originalAnnounce;
  originalAnnounce = undefined;
}

/** Observes current live regions in a document for delivered text changes. */
export function observeLiveRegions(doc: Document = document): void {
  disconnectLiveRegions();

  const regions = liveRegions(doc);
  if (regions.length === 0) {
    recordMeta("live region observer", "watching 0 live regions");
    return;
  }

  const MutationObserverConstructor =
    doc.defaultView?.MutationObserver ?? MutationObserver;

  for (const region of regions) {
    let lastText = region.textContent?.trim() ?? "";
    let lastRecordedText: string | undefined;
    const observer = new MutationObserverConstructor(() => {
      const text = region.textContent?.trim() ?? "";
      if (text === lastText) {
        return;
      }

      lastText = text;
      if (!text || text === lastRecordedText) {
        return;
      }

      if (recordSpoken(region, text)) {
        lastRecordedText = text;
      }
    });

    observer.observe(region, {
      childList: true,
      characterData: true,
      subtree: true,
    });
    liveRegionObservers.push(observer);
  }
}

/** Disconnects every live-region observer. */
export function disconnectLiveRegions(): void {
  for (const observer of liveRegionObservers) {
    observer.disconnect();
  }
  liveRegionObservers = [];
}

/** Attaches document interaction listeners in the capture phase. */
export function attachCapture(doc: Document = document): void {
  detachCapture();
  captureDocument = doc;

  for (const eventType of CAPTURE_EVENT_TYPES) {
    doc.addEventListener(eventType, captureEvent, true);
  }
}

/** Removes the capture listeners and invalidates their pending reads. */
export function detachCapture(): void {
  if (captureDocument) {
    for (const eventType of CAPTURE_EVENT_TYPES) {
      captureDocument.removeEventListener(eventType, captureEvent, true);
    }
  }

  captureDocument = undefined;
  captureGeneration++;
}

/** Returns the reactive module timeline. */
export function timelineEntries(): readonly TimelineEntry[] {
  return timeline;
}

/** Removes all surviving entries without changing sequence allocation. */
export function clearTimeline(): void {
  timeline.splice(0, timeline.length);
}

/** Enables or disables recording while leaving instrumentation attached. */
export function setPaused(value: boolean): void {
  paused = value;
  devToolsState.setFlag(TOOL_ID, "paused", value);
}

/** Enables or disables mirroring new entries to the console. */
export function setConsoleMirror(value: boolean): void {
  consoleMirror = value;
  devToolsState.setFlag(TOOL_ID, "consoleMirror", value);
}

/** Formats the surviving timeline as a copyable trace. */
export function copyTrace(): string {
  return timeline
    .map((entry) => `#${entry.seq} ${entry.label} ${entry.detail}`)
    .join("\n");
}

/** Fully tears down instrumentation and clears its test-facing state. */
export function resetA11yInstrumentation(): void {
  uninstallA11yTap();
  disconnectLiveRegions();
  detachCapture();
  clearTimeline();
  sequence = 0;
  setPaused(false);
  setConsoleMirror(false);
}
