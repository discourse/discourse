import { tracked } from "@glimmer/tracking";
import { trackedArray } from "@ember/reactive/collections";
import { cancel, later, next } from "@ember/runloop";
import { IDLE_ANNOUNCEMENT } from "discourse/components/a11y/live-regions";
import A11y from "discourse/services/a11y";
import { capabilities } from "discourse/services/capabilities";
import {
  isComposite,
  itemRolesFor,
  requiredPropsFor,
  requiresAccessibleName,
} from "discourse/static/dev-tools/a11y/aria";
import { beginPass } from "discourse/static/dev-tools/a11y/dom";
import {
  type Finding,
  finding,
  findingTrace,
} from "discourse/static/dev-tools/a11y/findings";
import {
  accessibleDescription,
  classifyCursor,
  compareCursors,
  composeUtterance,
  type Containment,
  type CursorAgreement,
  type CursorState,
  describeBarriers,
  describeContainment,
  describeElement,
  visualCursor,
} from "discourse/static/dev-tools/a11y/inspect";
import devToolsState from "discourse/static/dev-tools/state";

export type EntryKind = "event" | "intent" | "delivered" | "meta";

export interface A11ySnapshot {
  focused?: string;
  focusedLabel?: string;
  focusedDescription?: string;
  expanded?: string;
  cursorState: CursorState;
  cursorTarget?: string;
  cursorTargetPresent: boolean;
  cursorContainer?: string;
  cursorIndex?: number;
  cursorSize?: number;
  barrierSource?: string;
  inTree?: string;
  barriers?: string;
  /** The tree excludes it outright, computed styles included. */
  hidden: boolean;
  containmentKind: Containment["kind"];
  traceContainment?: string;
  inspectorContainment?: string;
  owns?: string;
  utterance?: string;
  rowSelected?: string;
  rowPosition?: string;
  visual?: string;
  agreement: CursorAgreement;
  multiselectable?: string;
  selectedCount?: number;
}

export interface TimelineEntry {
  seq: number;
  kind: EntryKind;
  label: string;
  /** The chord, one key per entry, for a panel that renders them as keycaps. */
  keys?: readonly string[];
  detail: string;
  findings: readonly Finding[];
  snapshot?: A11ySnapshot;
}

export const TIMELINE_LIMIT = 200;

const ANNOUNCEMENT_DELIVERY_DEADLINE_MS = 100;
// Provisional until real traces establish a useful repeat rate and window.
const RUNAWAY_REPEAT_LIMIT = 5;
const RUNAWAY_WINDOW_MS = 1000;

const TOOL_ID = "a11y";
// The dev-tools chrome and anything carrying the opt-out marker never enter
// the trace they help produce.
const TOOLBAR_SELECTOR = ".dev-tools-toolbar, [data-dev-tools-trace-exclude]";
const CORE_LIVE_REGION_SELECTORS = [
  "#a11y-announcements-polite",
  "#a11y-announcements-assertive",
] as const;
const LIVE_REGION_ROLES = {
  alert: "assertive",
  log: "polite",
  status: "polite",
} as const;
const CAPTURE_EVENT_TYPES = ["focusin", "keyup", "click"] as const;
const MODIFIER_KEYS = new Set(["Alt", "Control", "Meta", "Shift"]);
/**
 * What Apple keyboards print on the modifier keys. Elsewhere the DOM's own
 * names are kept: the product's shortcut helper folds meta into ctrl off Apple,
 * which is right for describing a shortcut and wrong for reporting a keypress.
 */
const APPLE_MODIFIER_GLYPHS: Record<string, string> = {
  Alt: "⌥",
  Control: "⌃",
  Meta: "⌘",
  Shift: "⇧",
};

type Announce = typeof A11y.prototype.announce;

/**
 * The watched set as the panel sees it.
 *
 * Every reader goes through here, and nothing reads the observer list directly:
 * a plain module variable is read once by a getter and never again, freezing
 * the readout at whatever was true on first render. @tracked cannot decorate a
 * bare binding, so it lives on a holder.
 */
class WatchState {
  @tracked findings: readonly Finding[] = [];
  @tracked liveRegions: readonly string[] = [];
  @tracked paused = devToolsState.getFlag(TOOL_ID, "paused") === true;
}

export interface SweepFinding extends Finding {
  readonly count: number;
}

export interface A11ySweepResult {
  readonly regions: number;
  readonly composites: number;
  readonly findings: readonly SweepFinding[];
}

interface WatchedRegion {
  channel: string;
  findings: readonly Finding[];
  key: string;
  region: Element;
  observer: MutationObserver;
}

interface PendingIntent {
  channel: string;
  seq: number;
  timer: ReturnType<typeof later>;
}

interface RegionHistory {
  delivered: boolean;
  element: Element;
}

interface RecentAnnouncement {
  channel: string;
  message: string;
  timestamp: number;
}

const timeline = trackedArray<TimelineEntry>();
const watchState = new WatchState();
let sequence = 0;
let consoleMirror = devToolsState.getFlag(TOOL_ID, "consoleMirror") === true;
let originalAnnounce: Announce | undefined;
const watchedRegions = new Map<string, WatchedRegion>();
let watchedDocument: Document | undefined;
let reportedWatchCount = false;
let captureDocument: Document | undefined;
let captureGeneration = 0;
const pendingIntents = new Map<number, PendingIntent>();
const recentAnnouncements: RecentAnnouncement[] = [];
const regionHistory = new Map<string, RegionHistory>();
/** Modifiers a recorded chord was holding, awaiting their own release. */
const heldByLastChord = new Set<string>();

/** One entry as plain text, which is what a pasted trace and the filter see. */
export function timelineEntryTrace(entry: TimelineEntry): string {
  const keys = entry.keys?.length ? ` ${entry.keys.join("+")}` : "";
  const findings = entry.findings.map(findingTrace);
  const suffix = findings.length ? ` | ${findings.join(" | ")}` : "";

  return `#${entry.seq} ${entry.label}${keys} ${entry.detail}${suffix}`;
}

function record(
  kind: EntryKind,
  label: string,
  detail: string,
  extra: {
    findings?: readonly Finding[];
    keys?: string[];
    snapshot?: A11ySnapshot;
  } = {}
): TimelineEntry | undefined {
  if (watchState.paused) {
    return undefined;
  }

  const entry: TimelineEntry = {
    seq: ++sequence,
    kind,
    label,
    detail,
    findings: Object.freeze([...(extra.findings ?? [])]),
    ...(extra.keys ? { keys: extra.keys } : {}),
    ...(extra.snapshot ? { snapshot: extra.snapshot } : {}),
  };

  timeline.push(entry);
  if (timeline.length > TIMELINE_LIMIT) {
    timeline.splice(0, timeline.length - TIMELINE_LIMIT);
  }

  if (consoleMirror) {
    // eslint-disable-next-line no-console
    console.log(`[a11y] ${timelineEntryTrace(entry)}`);
  }

  return entry;
}

function describeArgument(value: unknown): string {
  if (typeof value === "string") {
    return value;
  }

  return typeof value;
}

function channelFor(region: Element): string {
  const explicitPoliteness = region.getAttribute("aria-live")?.toLowerCase();
  const role = region.getAttribute("role")?.toLowerCase();

  return (
    explicitPoliteness ??
    (role
      ? LIVE_REGION_ROLES[role as keyof typeof LIVE_REGION_ROLES]
      : undefined) ??
    "off"
  );
}

function regionText(region: Element): string {
  const text = region.textContent ?? "";
  return text === IDLE_ANNOUNCEMENT ? "" : text.trim();
}

function regionKey(region: Element): string {
  if (region.id) {
    return `id:${region.id}`;
  }

  const path: string[] = [];
  let current: Element | null = region;
  while (current && current !== region.ownerDocument.body) {
    const tagName = current.tagName;
    const siblings = current.parentElement
      ? [...current.parentElement.children].filter(
          (sibling) => sibling.tagName === tagName
        )
      : [];
    path.unshift(
      `${current.tagName.toLowerCase()}:${siblings.indexOf(current) + 1}`
    );
    current = current.parentElement;
  }

  return `path:${path.join("/")}`;
}

function runawayFinding(
  message: unknown,
  channel: unknown
): Finding | undefined {
  if (typeof message !== "string" || typeof channel !== "string") {
    return undefined;
  }

  const timestamp = Date.now();
  while (
    recentAnnouncements[0] &&
    timestamp - recentAnnouncements[0].timestamp > RUNAWAY_WINDOW_MS
  ) {
    recentAnnouncements.shift();
  }
  recentAnnouncements.push({ channel, message, timestamp });

  const repeats = recentAnnouncements.filter(
    (announcement) =>
      announcement.channel === channel && announcement.message === message
  ).length;

  return repeats > RUNAWAY_REPEAT_LIMIT
    ? finding("announce.runaway", {
        channel,
        message,
        repeats,
        window: RUNAWAY_WINDOW_MS,
      })
    : undefined;
}

function scheduleUndelivered(seq: number, channel: string): void {
  const timer = later(() => {
    if (!pendingIntents.delete(seq)) {
      return;
    }

    record(
      "event",
      "announcement undelivered",
      `intent=#${seq} politeness=${channel}`,
      {
        findings: [finding("announce.undelivered", { channel, intent: seq })],
      }
    );
  }, ANNOUNCEMENT_DELIVERY_DEADLINE_MS);

  pendingIntents.set(seq, { channel, seq, timer });
}

function recordIntent(args: Parameters<Announce>): void {
  if (watchState.paused) {
    return;
  }

  const [message, politeness = "polite"] = args;
  const joinedRegions = watchedDocument
    ? discoverLiveRegions(watchedDocument)
    : [];
  const matchingRegions = [...watchedRegions.values()].filter(
    ({ channel }) => channel === politeness
  );
  const findings: Finding[] = [];

  if (matchingRegions.length === 0) {
    findings.push(finding("announce.no-region", { channel: politeness }));
  } else {
    const pass = beginPass();
    for (const { key, region } of matchingRegions) {
      if (pass.hidden(region)) {
        findings.push(
          finding("live.not-in-tree", { channel: politeness, region: key })
        );
      }
    }
  }

  for (const { channel, key, region } of joinedRegions) {
    if (channel !== politeness || !regionText(region)) {
      continue;
    }

    findings.push(
      finding(
        region.getAttribute("role")?.toLowerCase() === "alert"
          ? "live.born-with-content-alert"
          : "live.born-with-content",
        { channel, region: key }
      )
    );
  }

  const runaway = runawayFinding(message, politeness);
  if (runaway) {
    findings.push(runaway);
  }

  const entry = record(
    "intent",
    "announce intent",
    `politeness=${describeArgument(politeness)} "${describeArgument(message)}"`,
    { findings }
  );

  if (entry && typeof politeness === "string" && matchingRegions.length > 0) {
    scheduleUndelivered(entry.seq, politeness);
  }
}

function recordDelivered(region: Element, text: string): void {
  if (watchState.paused) {
    return;
  }

  const politeness = region.getAttribute("aria-live") ?? "?";
  const source = region.id || describeElement(region) || "anonymous";

  // The blank between two identical messages is what makes the second audible,
  // so it is recorded — but as `meta`, since counting a clear as a delivery
  // would let an intent that never arrived look answered.
  if (!text) {
    recordMeta("live region cleared", `region=${source}`);
    return;
  }

  const watched = [...watchedRegions.values()].find(
    (candidate) => candidate.region === region
  );
  if (watched) {
    const history = regionHistory.get(watched.key);
    if (history) {
      history.delivered = true;
    }

    const pending = [...pendingIntents.values()].find(
      (intent) => intent.channel === watched.channel
    );
    if (pending) {
      cancel(pending.timer);
      pendingIntents.delete(pending.seq);
    }
  }

  record("delivered", `delivered ${politeness}`, `region=${source} "${text}"`);
}

function recordMeta(label: string, detail: string): void {
  if (watchState.paused) {
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

  for (const region of doc.querySelectorAll(
    "[aria-live], [role='alert'], [role='log'], [role='status']"
  )) {
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

function attribute(element: Element | null, name: string): string | undefined {
  return element?.getAttribute(name) ?? undefined;
}

function hasTextOutsideAriaHiddenSubtrees(element: Element): boolean {
  for (const child of element.childNodes) {
    if (child.nodeType === Node.TEXT_NODE && child.textContent?.trim()) {
      return true;
    }

    if (
      child.nodeType === Node.ELEMENT_NODE &&
      (child as Element).getAttribute("aria-hidden")?.toLowerCase() !==
        "true" &&
      hasTextOutsideAriaHiddenSubtrees(child as Element)
    ) {
      return true;
    }
  }

  return false;
}

function labelKey(key: string): string {
  return capabilities.isApple ? (APPLE_MODIFIER_GLYPHS[key] ?? key) : key;
}

function integerAttribute(value: string | undefined): number | undefined {
  if (value === undefined || !/^[+-]?\d+$/.test(value.trim())) {
    return undefined;
  }

  const parsed = Number(value);
  return Number.isInteger(parsed) ? parsed : undefined;
}

function setPositionFindings(
  cursor: ReturnType<typeof classifyCursor>,
  position: string | undefined,
  size: string | undefined
): Finding[] {
  if (position === undefined && size === undefined) {
    return [];
  }

  const parsedPosition = integerAttribute(position);
  const parsedSize = integerAttribute(size);
  const impossible =
    (position !== undefined && parsedPosition === undefined) ||
    (size !== undefined && parsedSize === undefined) ||
    (parsedPosition !== undefined && parsedPosition < 1) ||
    (parsedPosition !== undefined &&
      parsedSize !== undefined &&
      parsedSize !== -1 &&
      parsedPosition > parsedSize);

  if (impossible) {
    return [
      finding("set.impossible", {
        ...(position !== undefined ? { posinset: position } : {}),
        ...(size !== undefined ? { setsize: size } : {}),
      }),
    ];
  }

  const disagrees =
    (parsedPosition !== undefined &&
      cursor.index !== undefined &&
      parsedPosition !== cursor.index + 1) ||
    (parsedSize !== undefined &&
      cursor.size !== undefined &&
      parsedSize !== cursor.size);

  return disagrees
    ? [
        finding("set.disagrees", {
          ...(position !== undefined ? { posinset: position } : {}),
          ...(size !== undefined ? { setsize: size } : {}),
          ...(cursor.index !== undefined
            ? { domPosition: cursor.index + 1 }
            : {}),
          ...(cursor.size !== undefined ? { domSize: cursor.size } : {}),
        }),
      ]
    : [];
}

const REQUIRED_STATE_PROPS: Readonly<Record<string, ReadonlySet<string>>> = {
  "aria-checked": new Set([
    "checkbox",
    "menuitemcheckbox",
    "menuitemradio",
    "radio",
    "switch",
  ]),
  "aria-valuenow": new Set(["scrollbar", "slider"]),
};

function nativeSemanticsSupply(
  element: Element,
  role: string,
  property: string
): boolean {
  const withoutRole = element.cloneNode(false) as Element;
  withoutRole.removeAttribute("role");
  if (beginPass().role(withoutRole) === role) {
    return true;
  }

  return (
    (property === "aria-checked" &&
      element.matches("input[type='checkbox'], input[type='radio']")) ||
    (property === "aria-valuenow" &&
      element.matches("input[type='range'], meter, progress")) ||
    (property === "aria-level" && element.matches("h1, h2, h3, h4, h5, h6"))
  );
}

function requiredAttributeFindings(
  element: Element,
  computedRole: string | undefined
): Finding[] {
  const authoredRole = element.getAttribute("role")?.trim().toLowerCase();
  if (!authoredRole || authoredRole !== computedRole) {
    return [];
  }

  const findings: Finding[] = [];
  for (const [property, defaultValue] of requiredPropsFor(authoredRole)) {
    if (
      element.hasAttribute(property) ||
      nativeSemanticsSupply(element, authoredRole, property)
    ) {
      continue;
    }

    const missingState =
      defaultValue === null &&
      REQUIRED_STATE_PROPS[property]?.has(authoredRole);
    const id = missingState
      ? "role.missing-state"
      : defaultValue === null
        ? "role.missing-attribute"
        : "role.missing-attribute-defaulted";

    findings.push(
      finding(id, {
        role: authoredRole,
        attribute: property,
        ...(defaultValue === null ? {} : { default: defaultValue }),
      })
    );
  }

  return findings;
}

/**
 * The chord as pressed, one key per entry, or nothing for the trailing release
 * of a chord already recorded.
 *
 * `keyup` fires once per physical key, so a chord ends in as many events as it
 * had keys held: Meta+C reports `c` and then `Meta`. That trailing `Meta` says
 * nothing the chord did not. A modifier pressed on its own still earns a row,
 * though: screen readers are driven by held modifiers, and a keypress that
 * leaves no trace cannot be told apart from capture being broken.
 */
function describeChord(event: KeyboardEvent): string[] | undefined {
  if (MODIFIER_KEYS.has(event.key)) {
    const trailingRelease =
      !event.getModifierState(event.key) && heldByLastChord.delete(event.key);

    return trailingRelease ? undefined : [labelKey(event.key)];
  }

  const modifiers = [
    event.metaKey ? "Meta" : "",
    event.ctrlKey ? "Control" : "",
    event.altKey ? "Alt" : "",
    event.shiftKey ? "Shift" : "",
  ].filter(Boolean);

  for (const modifier of modifiers) {
    heldByLastChord.add(modifier);
  }

  return [...modifiers.map(labelKey), event.key];
}

function snapshotFor(doc: Document): {
  findings: readonly Finding[];
  snapshot: A11ySnapshot;
} {
  const focused = doc.activeElement;
  const cursor = classifyCursor(focused);
  const { target, container } = cursor;
  const visual = visualCursor(container);
  const barrierSource = target ?? focused;
  const position = attribute(target, "aria-posinset");
  const size = attribute(target, "aria-setsize");
  const pass = beginPass();

  const description = focused ? accessibleDescription(focused) : "";
  const containment = describeContainment(focused, target);
  const agreement = compareCursors(target, visual);
  const hidden = barrierSource ? pass.hidden(barrierSource) : false;
  const snapshot: A11ySnapshot = {
    focused: describeElement(focused),
    focusedLabel: attribute(focused, "aria-label"),
    ...(description ? { focusedDescription: description } : {}),
    expanded: attribute(focused, "aria-expanded"),
    cursorState: cursor.state,
    cursorTarget: describeElement(target),
    cursorTargetPresent: Boolean(target),
    cursorContainer: describeElement(container),
    cursorIndex: cursor.index,
    cursorSize: cursor.size,
    barrierSource: describeElement(barrierSource),
    inTree: barrierSource ? (hidden ? "no — excluded" : "yes") : undefined,
    barriers: barrierSource
      ? describeBarriers(barrierSource).join(" > ") || undefined
      : undefined,
    hidden,
    containmentKind: containment.kind,
    traceContainment: describeContainmentText(containment),
    inspectorContainment:
      containment.kind === "claimed"
        ? `claimed via ${containment.via.join(", ")}`
        : containment.kind,
    owns: attribute(focused, "aria-owns"),
    utterance: target ? composeUtterance(target) : undefined,
    rowSelected: attribute(target, "aria-selected"),
    ...(position || size
      ? { rowPosition: `${position ?? "?"} / ${size ?? "?"}` }
      : {}),
    visual: describeElement(visual),
    agreement,
    multiselectable: attribute(container, "aria-multiselectable"),
    ...(container
      ? {
          selectedCount: container.querySelectorAll("[aria-selected='true']")
            .length,
        }
      : {}),
  };
  const findings: Finding[] = [];

  if (focused) {
    const focusedHidden = beginPass().hidden(focused);
    const name = pass.name(focused);
    const rawDescription = pass.description(focused);
    const role = pass.role(focused);
    const title = attribute(focused, "title");
    const hasExplicitDescription =
      focused.hasAttribute("aria-describedby") ||
      focused.hasAttribute("aria-description");
    const labelledBy = attribute(focused, "aria-labelledby")
      ?.trim()
      .split(/\s+/)
      .filter(Boolean);
    const resolvedLabelCount =
      labelledBy?.filter((id) => doc.getElementById(id)).length ?? 0;
    const nameCameFromTitle = Boolean(
      title &&
      name === title &&
      !focused.hasAttribute("aria-label") &&
      resolvedLabelCount === 0 &&
      !hasTextOutsideAriaHiddenSubtrees(focused)
    );

    if (focusedHidden) {
      findings.push(finding("focus.not-in-tree"));
    }
    if (role && requiresAccessibleName(role) && !name) {
      findings.push(finding("focus.no-name"));
    }
    if (hasExplicitDescription && rawDescription && rawDescription === name) {
      findings.push(finding("name.describedby-echoes-name"));
    }
    if (nameCameFromTitle) {
      findings.push(finding("name.from-title-only"));
    }
    if (
      !nameCameFromTitle &&
      title &&
      rawDescription === title &&
      rawDescription === name
    ) {
      findings.push(finding("name.title-duplicates-name"));
    }
    if (labelledBy) {
      if (resolvedLabelCount > 0 && resolvedLabelCount < labelledBy.length) {
        findings.push(finding("name.labelledby-partly-unresolved"));
      }
    }

    findings.push(...requiredAttributeFindings(focused, role));
  }

  if (snapshot.cursorState === "dangling") {
    findings.push(finding("cursor.dangling"));
  }
  if (snapshot.cursorState === "not_item") {
    findings.push(finding("cursor.not-item"));
  }
  if (snapshot.agreement === "diverged") {
    findings.push(finding("cursor.visual-diverged"));
  }
  if (snapshot.containmentKind === "unclaimed") {
    findings.push(finding("cursor.claim-missing"));
  }
  if (snapshot.hidden && snapshot.cursorTargetPresent) {
    findings.push(finding("cursor.target-hidden"));
  }
  findings.push(...setPositionFindings(cursor, position, size));

  return {
    findings: Object.freeze(findings),
    snapshot,
  };
}

function describeCursorState(state: CursorState): string | undefined {
  switch (state) {
    case "absent":
      return undefined;
    case "dangling":
      return "NO — dangling";
    case "not_item":
      return "NO — target is not an item of its container";
    case "ok":
      return "yes";
  }
}

function describeAgreement(snapshot: A11ySnapshot): string | undefined {
  switch (snapshot.agreement) {
    case "agree":
      return "yes";
    case "diverged":
      return "NO — visual and ARIA cursors differ";
    case "unknown":
      return undefined;
  }
}

function describeContainmentText(containment: Containment): string | undefined {
  switch (containment.kind) {
    case "none":
      return undefined;
    case "descendant":
      return "DOM descendant";
    case "claimed":
      return `portaled, claimed by ${containment.via.join(" + ")}`;
    case "unclaimed":
      return "portaled, UNCLAIMED";
  }
}

/**
 * The snapshot as one readable line, with unset fields omitted. Omission does
 * the scanning: a plain focus move stays one short line, and an event gets long
 * precisely because there is something to look at.
 *
 * No `aria-label` field — `describeElement` already prefers the accessible
 * name, so printing the label too would repeat it on every row.
 */
export function summarize(snapshot: A11ySnapshot): string {
  return (
    [
      ["focus", snapshot.focused],
      [
        "describedby",
        snapshot.focusedDescription
          ? `"${snapshot.focusedDescription}"`
          : undefined,
      ],
      ["expanded", snapshot.expanded],
      [
        "ad",
        snapshot.cursorState === "absent"
          ? undefined
          : (snapshot.cursorTarget ?? "(unresolved)"),
      ],
      ["resolves", describeCursorState(snapshot.cursorState)],
      [
        "position",
        snapshot.cursorIndex === undefined
          ? snapshot.rowPosition
          : `${snapshot.cursorIndex + 1} / ${snapshot.cursorSize}`,
      ],
      ["selected", snapshot.rowSelected],
      ["visual", snapshot.visual],
      ["agree", describeAgreement(snapshot)],
      ["hidden", snapshot.hidden ? "YES — excluded from the tree" : undefined],
      ["barriers", snapshot.barriers],
      ["containment", snapshot.traceContainment],
      ["says", snapshot.utterance ? `"${snapshot.utterance}"` : undefined],
    ] as const
  )
    .filter(([, value]) => Boolean(value))
    .map(([key, value]) => `${key}=${value}`)
    .join(" ");
}

function captureEvent(event: Event): void {
  const doc = event.currentTarget;
  if (!(doc instanceof Document) || eventStartsInToolbar(event, doc)) {
    return;
  }

  // Read synchronously: the event object is not guaranteed to still carry its
  // properties by the time the queued read runs.
  let keys: string[] | undefined;
  if (event instanceof KeyboardEvent) {
    keys = describeChord(event);
    if (!keys) {
      return;
    }
  }

  const label = event.type;
  const generation = captureGeneration;

  next(() => {
    if (generation !== captureGeneration || captureDocument !== doc) {
      return;
    }

    attachLiveRegions(doc);

    const { findings, snapshot } = snapshotFor(doc);
    record("event", label, summarize(snapshot), { findings, keys, snapshot });
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

/** Enough to tell one region from another in the trace. */
function describeRegion(region: Element): string {
  const politeness = region.getAttribute("aria-live") ?? "off";
  return `${region.id ? `#${region.id}` : (describeElement(region) ?? "anonymous")} (${politeness})`;
}

function liveRegionMarkupFindings(region: Element): readonly Finding[] {
  const role = region.getAttribute("role")?.toLowerCase();
  const explicitPoliteness = region.getAttribute("aria-live")?.toLowerCase();
  const impliedPoliteness = role
    ? LIVE_REGION_ROLES[role as keyof typeof LIVE_REGION_ROLES]
    : undefined;

  if (!role || !impliedPoliteness || !explicitPoliteness) {
    return [];
  }

  const id =
    impliedPoliteness === explicitPoliteness
      ? "live.redundant-politeness"
      : "live.politeness-contradicts-role";

  return [
    finding(id, {
      region:
        (region.id ? `#${region.id}` : describeElement(region)) ?? "anonymous",
      role,
      impliedPoliteness,
      explicitPoliteness,
    }),
  ];
}

function addSweepFindings(
  aggregated: Map<string, { finding: Finding; elements: Set<Element> }>,
  element: Element,
  findings: readonly Finding[]
): void {
  for (const candidate of findings) {
    if (
      candidate.tier === "noted" ||
      candidate.id.startsWith("focus.") ||
      candidate.id.startsWith("name.")
    ) {
      continue;
    }

    const existing = aggregated.get(candidate.id);
    if (existing) {
      existing.elements.add(element);
    } else {
      aggregated.set(candidate.id, {
        finding: candidate,
        elements: new Set([element]),
      });
    }
  }
}

function compositeFindings(composite: Element): Map<Element, Finding[]> {
  const pass = beginPass();
  const role = pass.role(composite);
  const findings = new Map<Element, Finding[]>([
    [composite, requiredAttributeFindings(composite, role)],
  ]);
  const cursor = classifyCursor(composite);
  const { target } = cursor;

  if (cursor.state === "dangling") {
    findings.get(composite)!.push(finding("cursor.dangling"));
  } else if (cursor.state === "not_item") {
    findings.get(composite)!.push(finding("cursor.not-item"));
  }

  if (target) {
    const targetFindings = findings.get(target) ?? [];
    const visual = visualCursor(cursor.container);
    const containment = describeContainment(composite, target);

    if (compareCursors(target, visual) === "diverged") {
      targetFindings.push(finding("cursor.visual-diverged"));
    }
    if (containment.kind === "unclaimed") {
      targetFindings.push(finding("cursor.claim-missing"));
    }
    if (pass.hidden(target)) {
      targetFindings.push(finding("cursor.target-hidden"));
    }
    targetFindings.push(
      ...setPositionFindings(
        cursor,
        attribute(target, "aria-posinset"),
        attribute(target, "aria-setsize")
      )
    );
    findings.set(target, targetFindings);
  }

  if (role) {
    const itemRoles = itemRolesFor(role);
    const items = [...composite.querySelectorAll("*")].filter((element) => {
      let itemRole = pass.role(element) ?? "";
      if (itemRole === "cell" && (role === "grid" || role === "treegrid")) {
        itemRole = "gridcell";
      }

      return !pass.hidden(element) && itemRoles.has(itemRole);
    });

    for (const [index, item] of items.entries()) {
      const itemFindings = findings.get(item) ?? [];
      itemFindings.push(...requiredAttributeFindings(item, pass.role(item)));
      itemFindings.push(
        ...setPositionFindings(
          {
            state: "ok",
            target: item,
            container: composite,
            index,
            size: items.length,
          },
          attribute(item, "aria-posinset"),
          attribute(item, "aria-setsize")
        )
      );
      findings.set(item, itemFindings);
    }
  }

  return findings;
}

/** Checks the current document on demand without changing capture state. */
export function sweepA11y(doc: Document = document): A11ySweepResult {
  const pass = beginPass();
  const regions = liveRegions(doc);
  const composites = [...doc.querySelectorAll("*")].filter((element) => {
    const role = pass.role(element);

    return (
      !isToolbarElement(element) &&
      !pass.hidden(element) &&
      Boolean(role && isComposite(role))
    );
  });
  const aggregated = new Map<
    string,
    { finding: Finding; elements: Set<Element> }
  >();

  for (const region of regions) {
    const findings = [...liveRegionMarkupFindings(region)];
    if (pass.hidden(region)) {
      findings.push(
        finding("live.not-in-tree", {
          channel: channelFor(region),
          region: regionKey(region),
        })
      );
    }
    addSweepFindings(aggregated, region, findings);
  }

  for (const composite of composites) {
    for (const [element, findings] of compositeFindings(composite)) {
      addSweepFindings(aggregated, element, findings);
    }
  }

  return Object.freeze({
    regions: regions.length,
    composites: composites.length,
    findings: Object.freeze(
      [...aggregated.values()].map(({ finding: candidate, elements }) =>
        Object.freeze({ ...candidate, count: elements.size })
      )
    ),
  });
}

function updateWatchState(): void {
  watchState.findings = [...watchedRegions.values()].flatMap(
    ({ findings }) => findings
  );
  watchState.liveRegions = [...watchedRegions.values()].map(({ region }) =>
    describeRegion(region)
  );
}

/** Stops watching regions that have left the document, naming each one. */
function releaseDetachedRegions(): void {
  for (const [key, { region, observer }] of watchedRegions) {
    if (region.isConnected) {
      continue;
    }

    observer.disconnect();
    watchedRegions.delete(key);
    recordMeta("live region left", describeRegion(region));
  }
}

export function pruneDetachedLiveRegions(): void {
  releaseDetachedRegions();
  updateWatchState();
}

/**
 * Watches every live region in a document that is not already watched, and
 * releases the ones that have gone.
 *
 * Called again on every captured event, because regions appear over the life of
 * a page: the shared ones render after the panel on a cold load, and a modal
 * brings its own. A one-shot scan attaches to nothing and then reports a
 * silence indistinguishable from a page that never announced.
 *
 * The count is of regions present RIGHT NOW. A running total would climb every
 * time a modal opened and closed, and a number that only ever rises cannot tell
 * a leak from bookkeeping — which is why each arrival and departure is named.
 */
function discoverLiveRegions(doc: Document, baseline = false): WatchedRegion[] {
  const MutationObserverConstructor =
    doc.defaultView?.MutationObserver ?? MutationObserver;
  const joinedRegions: WatchedRegion[] = [];

  watchedDocument = doc;
  releaseDetachedRegions();

  for (const region of liveRegions(doc)) {
    const key = regionKey(region);
    const existing = watchedRegions.get(key);
    if (existing) {
      continue;
    }

    // A text change is one delivery to the region. Nothing beyond that is
    // deduplicated: a message repeated after the region idles is a second real
    // delivery, and hiding it hides the bug this panel is for.
    let lastText = regionText(region);
    const observer = new MutationObserverConstructor(() => {
      const text = regionText(region);
      if (text === lastText) {
        return;
      }

      lastText = text;
      recordDelivered(region, text);
    });

    observer.observe(region, {
      childList: true,
      characterData: true,
      subtree: true,
    });
    const channel = channelFor(region);
    const findings = liveRegionMarkupFindings(region);
    const previous = regionHistory.get(key);
    const watched = {
      channel,
      findings,
      key,
      observer,
      region,
    };
    watchedRegions.set(key, watched);
    joinedRegions.push(watched);

    if (previous && previous.element !== region && previous.delivered) {
      record("event", "live region replaced", describeRegion(region), {
        findings: [
          finding("live.replaced-mid-session", { channel, region: key }),
        ],
      });
    }
    regionHistory.set(key, {
      delivered: previous?.delivered ?? false,
      element: region,
    });

    if (!baseline) {
      recordMeta("live region joined", describeRegion(region));
    }
  }

  updateWatchState();
  return joinedRegions;
}

export function attachLiveRegions(doc: Document = document): void {
  // The set present when watching starts is the baseline the chip names. Only
  // what changes afterwards is news worth a row.
  const baseline = !reportedWatchCount;

  discoverLiveRegions(doc, baseline);

  // The one baseline worth a row: nothing can be verified from here.
  if (baseline && watchedRegions.size === 0) {
    recordMeta("live region observer", "watching 0 live regions");
  }
  reportedWatchCount = true;
}

/** How many live regions are attached right now. Reactive. */
export function watchedLiveRegionCount(): number {
  return watchState.liveRegions.length;
}

/** Which live regions are attached right now, named. Reactive. */
export function watchedLiveRegions(): readonly string[] {
  return watchState.liveRegions;
}

/** Findings concluded once for the live regions currently being watched. */
export function liveRegionFindings(): readonly Finding[] {
  return watchState.findings;
}

/** Disconnects every live-region observer. */
export function disconnectLiveRegions(): void {
  for (const { observer } of watchedRegions.values()) {
    observer.disconnect();
  }
  watchedRegions.clear();
  watchedDocument = undefined;
  watchState.findings = [];
  watchState.liveRegions = [];
  reportedWatchCount = false;
}

/** Attaches document interaction listeners in the capture phase. */
export function attachCapture(doc: Document = document): void {
  detachCapture();
  captureDocument = doc;

  for (const eventType of CAPTURE_EVENT_TYPES) {
    doc.addEventListener(eventType, captureEvent, true);
  }
  doc.addEventListener("visibilitychange", clearHeldChord);
  doc.defaultView?.addEventListener("blur", clearHeldChord);
}

function clearHeldChord(): void {
  heldByLastChord.clear();
}

/** Removes the capture listeners and invalidates their pending reads. */
export function detachCapture(): void {
  if (captureDocument) {
    for (const eventType of CAPTURE_EVENT_TYPES) {
      captureDocument.removeEventListener(eventType, captureEvent, true);
    }
    captureDocument.removeEventListener("visibilitychange", clearHeldChord);
    captureDocument.defaultView?.removeEventListener("blur", clearHeldChord);
  }

  captureDocument = undefined;
  captureGeneration++;
  heldByLastChord.clear();
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
  watchState.paused = value;
  devToolsState.setFlag(TOOL_ID, "paused", value);
}

/** Whether recording is currently paused. Reactive for panel consumers. */
export function isPaused(): boolean {
  return watchState.paused;
}

/** Enables or disables mirroring new entries to the console. */
export function setConsoleMirror(value: boolean): void {
  consoleMirror = value;
  devToolsState.setFlag(TOOL_ID, "consoleMirror", value);
}

/** Formats the surviving timeline as a copyable trace. */
export function copyTrace(): string {
  return timeline.map(timelineEntryTrace).join("\n");
}

/** Fully tears down instrumentation and clears its test-facing state. */
export function resetA11yInstrumentation(): void {
  uninstallA11yTap();
  disconnectLiveRegions();
  detachCapture();
  clearTimeline();
  for (const { timer } of pendingIntents.values()) {
    cancel(timer);
  }
  pendingIntents.clear();
  recentAnnouncements.splice(0, recentAnnouncements.length);
  regionHistory.clear();
  sequence = 0;
  setPaused(false);
  setConsoleMirror(false);
}
