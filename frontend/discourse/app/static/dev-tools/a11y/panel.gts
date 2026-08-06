import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import type { TemplateOnlyComponent } from "@ember/component/template-only";
import { registerDestructor } from "@ember/destroyable";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { cancel, next, throttle } from "@ember/runloop";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import DMenu from "discourse/float-kit/components/d-menu";
import type DMenuInstance from "discourse/float-kit/lib/d-menu-instance";
import A11y from "discourse/services/a11y";
import {
  type Finding,
  findingKey,
  isProblem,
} from "discourse/static/dev-tools/a11y/findings";
import { isAtBottom } from "discourse/static/dev-tools/a11y/follow";
import type { CursorAgreement } from "discourse/static/dev-tools/a11y/inspect";
import {
  type A11ySweepResult,
  attachCapture,
  attachLiveRegions,
  clearTimeline,
  copyTrace,
  detachCapture,
  type ElementHandleField,
  hasElementHandle,
  isPaused,
  logElementHandle,
  logSweepHandle,
  mutedLiveRegionKeys,
  pruneDetachedLiveRegions,
  setPaused,
  sweepA11y,
  type SweepFinding,
  timelineEntries,
  type TimelineEntry,
  timelineEntryTrace,
  toggleLiveRegionMuted,
  watchedLiveRegionCount,
  watchedLiveRegionDetails,
  watchedLiveRegions,
} from "discourse/static/dev-tools/a11y/instrumentation";
import { project, type Row } from "discourse/static/dev-tools/a11y/projection";
import {
  onRunExpanded,
  onRunMemberPicked,
  type RunSubject,
  type SelectedSubject,
  subjectKey,
} from "discourse/static/dev-tools/a11y/subject";
import { and, eq, not, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import DFilterInput from "discourse/ui-kit/d-filter-input";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

type View = "timeline" | "regions" | "sweep";

interface DisplayRow extends Row {
  broken: Finding[];
  cause: string;
  elapsed: string | undefined;
  entries: TimelineEntry[];
  expanded: boolean;
  fragile: Finding[];
  hasDelivered: boolean;
  hasEvent: boolean;
  hasIntent: boolean;
  hasMeta: boolean;
  inspected: boolean;
  keys: readonly string[];
  latency: string | undefined;
  memberRows: DisplayRow[];
  noted: Finding[];
  noiseName: string;
  region: string | undefined;
  selectSeq: number;
  selected: boolean;
  undelivered: boolean;
  utterance: string | undefined;
}

interface EntryRowSignature {
  Args: {
    onSelect: () => void;
    row: DisplayRow;
  };
}

interface A11yPanelSignature {
  Element: HTMLDivElement;
}

interface InspectorSignature {
  Args: {
    canLogElement: boolean;
    facts: readonly InspectorRow[];
    hasBrokenFinding: boolean;
    hasDetails: boolean;
    identity: string | undefined;
    muted: boolean;
    onToggleMute: () => void;
    regionKey: string | undefined;
    onLogElement: () => void;
    snapshotFindings: readonly Finding[];
    utterance: string | undefined;
  };
}

interface InspectorRow {
  label: string;
  value: string;
}

interface DisplayRegion {
  broken: readonly Finding[];
  channel: string;
  deliveries: number;
  description: string;
  fragile: readonly Finding[];
  key: string;
  lastText: string;
  muted: boolean;
  noted: readonly Finding[];
  outOfTree: boolean;
}

interface DisplaySweepFinding extends SweepFinding {
  expanded: boolean;
}

const AGREEMENT_LABELS: Record<CursorAgreement, string | undefined> = {
  agree: "yes",
  diverged: "NO — visual and ARIA cursors differ",
  unknown: undefined,
};

/** Drops rows with nothing to show, so an unset field costs no screen space. */
function presentRows(
  rows: Array<{ label: string; value: string | undefined }>
): InspectorRow[] {
  return rows.filter((row): row is InspectorRow => Boolean(row.value));
}

function duration(milliseconds: number | undefined): string | undefined {
  if (milliseconds === undefined) {
    return undefined;
  }

  return milliseconds < 1000
    ? i18n("dev_tools.a11y.duration_ms", {
        value: Math.round(milliseconds),
      })
    : i18n("dev_tools.a11y.duration_s", {
        value: (milliseconds / 1000).toFixed(1),
      });
}

function signedDuration(milliseconds: number | undefined): string | undefined {
  const formatted = duration(milliseconds);
  return formatted ? `+${formatted}` : undefined;
}

function announcementChannel(entries: readonly TimelineEntry[]) {
  const intent = entries.find(({ kind }) => kind === "intent");
  const fromIntent = intent?.detail.match(/(?:^|\s)politeness=([^\s]+)/)?.[1];
  if (fromIntent) {
    return fromIntent;
  }

  return entries
    .find(({ kind }) => kind === "delivered")
    ?.label.replace(/^delivered\s+/, "");
}

function causeFor(entries: readonly TimelineEntry[]): string {
  const channel = announcementChannel(entries);
  if (channel) {
    return i18n("dev_tools.a11y.cause_announce", { channel });
  }

  const label = entries[0].label;
  if (label === "focusin") {
    return i18n("dev_tools.a11y.cause_focus");
  }
  if (label === "live region replaced") {
    return i18n("dev_tools.a11y.cause_replaced");
  }

  return label;
}

function deliveredMessage(entry: TimelineEntry | undefined) {
  if (!entry) {
    return undefined;
  }

  const firstQuote = entry.detail.indexOf('"');
  const lastQuote = entry.detail.lastIndexOf('"');
  return firstQuote >= 0 && lastQuote > firstQuote
    ? entry.detail.slice(firstQuote + 1, lastQuote)
    : undefined;
}

function utteranceFor(entries: readonly TimelineEntry[]) {
  return (
    entries.find(({ kind }) => kind === "intent")?.message ??
    deliveredMessage(entries.find(({ kind }) => kind === "delivered")) ??
    entries.find(({ snapshot }) => snapshot?.utterance)?.snapshot?.utterance
  );
}

function regionFor(entries: readonly TimelineEntry[]) {
  const delivery = entries.find(({ kind }) => kind === "delivered");
  const deliveredRegion = delivery?.detail.match(/^region=(.*?)\s+"/)?.[1];
  if (deliveredRegion) {
    const channel = delivery!.label.replace(/^delivered\s+/, "");
    return i18n("dev_tools.a11y.region_channel", {
      channel,
      region: deliveredRegion,
    });
  }

  const lifecycle = entries.find(({ label }) =>
    label.startsWith("live region ")
  );
  const describedRegion = lifecycle?.detail.match(/^#?(.*?)\s+\(([^)]+)\)$/);
  return describedRegion
    ? i18n("dev_tools.a11y.region_channel", {
        channel: describedRegion[2],
        region: describedRegion[1],
      })
    : undefined;
}

const EntryRow: TemplateOnlyComponent<EntryRowSignature> = <template>
  <button
    type="button"
    class={{dConcatClass
      "dev-tools-a11y__entry"
      (if @row.hasIntent "--intent")
      (if @row.hasDelivered "--delivered")
      (if @row.hasEvent "--event")
      (if @row.hasMeta "--meta")
      (if (eq @row.severity "danger") "--broken")
      (if (eq @row.severity "highlight") "--fragile")
      (if @row.selected "--selected")
    }}
    aria-pressed={{if @row.selected "true" "false"}}
    {{on "click" @onSelect}}
  >
    <span class="dev-tools-a11y__entry-rail"></span>
    <span class="dev-tools-a11y__entry-cause">
      {{#if @row.keys.length}}
        {{~#each @row.keys as |key|~}}
          <kbd class="dev-tools-a11y__key">{{key}}</kbd>
        {{~/each~}}
      {{else}}
        {{@row.cause}}
      {{/if}}
    </span>
    <span class="dev-tools-a11y__entry-say">
      {{#if @row.utterance}}
        <q class="dev-tools-a11y__entry-utterance">{{~@row.utterance~}}</q>
      {{else}}
        <span class="dev-tools-a11y__entry-silent" aria-hidden="true"></span>
      {{/if}}
      {{#if @row.region}}
        <span class="dev-tools-a11y__entry-dim">{{@row.region}}</span>
      {{/if}}
      {{#if @row.latency}}
        <span class="dev-tools-a11y__entry-latency">{{~@row.latency~}}</span>
      {{/if}}
    </span>
    <span class="dev-tools-a11y__entry-meta">
      <span class="dev-tools-a11y__entry-seq">
        {{~@row.seqLabel~}}
        {{~#if @row.elapsed}} · {{@row.elapsed}}{{/if~}}
      </span>
    </span>
    {{#if @row.undelivered}}
      <span
        class="dev-tools-a11y__entry-message --broken dev-tools-a11y__problem dev-tools-a11y__not-delivered"
        title={{i18n "dev_tools.a11y.not_delivered_title"}}
      >
        {{i18n "dev_tools.a11y.findings.announce.undelivered"}}
      </span>
    {{/if}}
    {{#each @row.broken as |finding|}}
      <span
        class="dev-tools-a11y__entry-message --broken dev-tools-a11y__problem"
      >{{i18n (findingKey finding.id) finding.params}}</span>
    {{/each}}
    {{#each @row.fragile as |finding|}}
      <span
        class="dev-tools-a11y__entry-message --fragile dev-tools-a11y__finding"
      >{{i18n (findingKey finding.id) finding.params}}</span>
    {{/each}}
    {{#each @row.noted as |finding|}}
      <span
        class="dev-tools-a11y__entry-message dev-tools-a11y__finding --noted"
      >
        {{i18n (findingKey finding.id) finding.params}}
      </span>
    {{/each}}
  </button>
</template>;

const Inspector: TemplateOnlyComponent<InspectorSignature> = <template>
  {{#if @hasDetails}}
    {{#if @utterance}}
      <p
        class={{dConcatClass
          "dev-tools-a11y__inspector-utterance"
          (if @hasBrokenFinding "--broken")
        }}
      >{{@utterance}}</p>
    {{/if}}
    {{#each @snapshotFindings as |finding|}}
      <p
        class={{dConcatClass
          "dev-tools-a11y__inspector-message"
          (if (eq finding.tier "broken") "--broken")
          (if (eq finding.tier "fragile") "--fragile")
        }}
      >{{i18n (findingKey finding.id) finding.params}}</p>
    {{/each}}
    {{#if @identity}}
      <div class="dev-tools-a11y__inspector-identity">
        <span>{{@identity}}</span>
        {{#if @canLogElement}}
          <DButton
            class="dev-tools-a11y__inspector-log"
            @display="link"
            @label="dev_tools.a11y.log_element"
            @action={{@onLogElement}}
          />
        {{/if}}
      </div>
    {{/if}}
    {{#if @regionKey}}
      <DButton
        class="btn-transparent dev-tools-a11y__mute"
        @translatedLabel={{i18n
          (if @muted "dev_tools.a11y.unmute" "dev_tools.a11y.mute")
        }}
        @translatedAriaLabel={{i18n
          (if
            @muted "dev_tools.a11y.unmute_region" "dev_tools.a11y.mute_region"
          )
          region=@regionKey
        }}
        @ariaPressed={{@muted}}
        @action={{@onToggleMute}}
      />
    {{/if}}
    {{#if @facts.length}}
      <dl class="dev-tools-a11y__inspector-facts">
        {{#each @facts as |row|}}
          <dt>{{row.label}}</dt><dd>{{row.value}}</dd>
        {{/each}}
      </dl>
    {{/if}}
  {{else}}
    <p class="dev-tools-panel__empty dev-tools-a11y__no-snapshot">
      {{i18n "dev_tools.a11y.no_snapshot"}}
    </p>
  {{/if}}
</template>;

export default class A11yPanel extends Component<A11yPanelSignature> {
  @service declare a11y: A11y;

  @tracked copied = false;
  @tracked expandedRunIds = new Set<string>();
  @tracked filter = "";
  @tracked following = true;
  @tracked hasOverflow = false;
  @tracked problemsOnly = false;
  @tracked selectedSeq?: number;
  @tracked selectedSubject?: SelectedSubject;
  @tracked sweepResult?: A11ySweepResult;
  @tracked expandedSweepFindingIds = new Set<string>();
  @tracked unseenCount = 0;
  @tracked view: View = "timeline";
  @tracked viewportHeight = 100;
  @tracked viewportTop = 0;
  #document?: Document;
  #latestSeq = 0;
  #pendingArrivals = 0;
  #resizeHandler?: ReturnType<typeof throttle>;
  #resizeObserver?: ResizeObserver;
  #rowsChangedHandler?: ReturnType<typeof next>;
  #scroller?: HTMLElement;
  #scrollHandler?: ReturnType<typeof throttle>;
  #scrollListener = () => this.#scheduleScrollCheck();
  #scrollToBottomHandler?: ReturnType<typeof next>;
  #testMenu?: DMenuInstance;

  get paused() {
    return isPaused();
  }

  // What is watched, not what is in the DOM: a region the observer never
  // attached to verifies nothing, and counting it would claim coverage.
  get liveRegionCount() {
    return watchedLiveRegionCount();
  }

  // A bare count cannot separate a leak from bookkeeping.
  get liveRegionTitle() {
    const regions = watchedLiveRegions();

    return regions.length
      ? regions.join("\n")
      : i18n("dev_tools.a11y.chip_regions_title");
  }

  get regions(): DisplayRegion[] {
    // Consume both tracked sources: discovery changes region facts, while a
    // delivery changes its count and last text as it appends to the timeline.
    watchedLiveRegionCount();
    timelineEntries();

    const regions: DisplayRegion[] = watchedLiveRegionDetails().map(
      (region) => ({
        ...region,
        broken: region.findings.filter(({ tier }) => tier === "broken"),
        fragile: region.findings.filter(({ tier }) => tier === "fragile"),
        noted: region.findings.filter(({ tier }) => tier === "noted"),
      })
    );

    const historicalRegionKeys = new Set(mutedLiveRegionKeys());
    for (const row of project(timelineEntries()).rows) {
      if (row.subject.kind === "region") {
        historicalRegionKeys.add(row.subject.regionKey);
      }
    }

    for (const regionKey of historicalRegionKeys) {
      if (!regions.some(({ key }) => key === regionKey)) {
        const region = this.#historicalRegion(regionKey);
        if (region) {
          regions.push(region);
        }
      }
    }

    return regions;
  }

  get sweepFindings(): DisplaySweepFinding[] {
    return (this.sweepResult?.findings ?? []).map((finding) => ({
      ...finding,
      expanded: this.expandedSweepFindingIds.has(finding.id),
    }));
  }

  @cached
  get projectedTimeline() {
    const entries = timelineEntries();
    const mutedRegionKeys = mutedLiveRegionKeys();

    return {
      entries,
      rows: project(entries).rows.filter(
        ({ subject }) =>
          subject.kind !== "region" || !mutedRegionKeys.has(subject.regionKey)
      ),
    };
  }

  get entries(): DisplayRow[] {
    const { entries, rows } = this.projectedTimeline;
    const entriesBySeq = new Map(entries.map((entry) => [entry.seq, entry]));
    const filter = this.filter.trim().toLowerCase();
    const inspectedSeq = this.selectedEntry?.seq;

    const displayRow = (row: Row): DisplayRow => {
      const memberEntries = row.members.flatMap((seq) => {
        const entry = entriesBySeq.get(seq);
        return entry ? [entry] : [];
      });
      const undelivered = row.findings.some(
        ({ id }) => id === "announce.undelivered"
      );
      const expanded =
        row.subject.kind === "run" && this.expandedRunIds.has(row.id);

      return {
        ...row,
        broken: row.findings.filter(
          (finding) =>
            finding.id !== "announce.undelivered" && isProblem(finding)
        ),
        cause: causeFor(memberEntries),
        elapsed: duration(row.elapsedMs),
        entries: memberEntries,
        expanded,
        fragile: row.findings.filter((finding) => finding.tier === "fragile"),
        hasDelivered: memberEntries.some(({ kind }) => kind === "delivered"),
        hasEvent: memberEntries.some(({ kind }) => kind === "event"),
        hasIntent: memberEntries.some(({ kind }) => kind === "intent"),
        hasMeta: memberEntries.some(({ kind }) => kind === "meta"),
        inspected:
          inspectedSeq !== undefined && row.members.includes(inspectedSeq),
        keys:
          memberEntries.find(({ keys }) => keys?.length)?.keys ?? ([] as const),
        latency: signedDuration(row.latencyMs),
        memberRows: expanded
          ? memberEntries.map((entry) => displayRow(project([entry]).rows[0]))
          : [],
        noiseName:
          row.subject.kind === "region"
            ? i18n("dev_tools.a11y.noise_churn_name", {
                region: row.subject.regionKey,
              })
            : causeFor(memberEntries),
        noted: row.findings.filter((finding) => finding.tier === "noted"),
        region: regionFor(memberEntries),
        selectSeq: row.members[0],
        selected:
          this.selectedSubject !== undefined &&
          row.id === subjectKey(this.selectedSubject),
        undelivered,
        utterance: utteranceFor(memberEntries),
      };
    };

    this.#projectedRowsChanged(rows);

    return rows
      .map((row) => {
        return displayRow(row);
      })
      .filter(({ entries: memberEntries, findings }) => {
        const matchesText =
          !filter ||
          memberEntries.some((entry) =>
            timelineEntryTrace(entry).toLowerCase().includes(filter)
          );
        const matchesProblems = !this.problemsOnly || findings.some(isProblem);
        return matchesText && matchesProblems;
      });
  }

  get hasInspectedRow() {
    return this.entries.some(({ inspected }) => inspected);
  }

  get densityMarks() {
    const { rows } = this.projectedTimeline;

    return rows.flatMap((row, rowIndex) =>
      row.findings
        .filter(({ tier }) => tier === "broken" || tier === "fragile")
        .map((finding, findingIndex) => ({
          key: `${row.id}-${finding.id}-${findingIndex}`,
          modifier: finding.tier === "broken" ? "--broken" : "--fragile",
          style: trustHTML(`top: ${(rowIndex / rows.length) * 100}%;`),
        }))
    );
  }

  get viewportStyle() {
    return trustHTML(
      `top: ${this.viewportTop}%; height: ${this.viewportHeight}%;`
    );
  }

  get latestEvent() {
    const entries = timelineEntries();
    for (let index = entries.length - 1; index >= 0; index--) {
      if (entries[index].kind === "event") {
        return entries[index];
      }
    }

    return undefined;
  }

  get snapshot() {
    return this.selectedEntry?.snapshot;
  }

  get inspectedRegion() {
    const subject = this.selectedSubject;
    if (subject?.kind !== "region") {
      return undefined;
    }

    return (
      this.regions.find(({ key }) => key === subject.regionKey) ??
      this.#historicalRegion(subject.regionKey)
    );
  }

  get inspectorUtterance() {
    const snapshot = this.snapshot;
    if (!snapshot) {
      return this.selectedUtterance;
    }

    return (
      snapshot.utterance ??
      [
        snapshot.focusedLabel ?? snapshot.focused?.split(" · ").at(-1),
        snapshot.focusedDescription,
      ]
        .filter((part): part is string => Boolean(part))
        .join(", ")
    );
  }

  get inspectorIdentity() {
    if (this.inspectedRegion) {
      return this.inspectedRegion.description;
    }

    const snapshot = this.snapshot;
    return snapshot?.cursorTarget ?? snapshot?.focused;
  }

  get inspectedElementField(): ElementHandleField {
    return this.snapshot?.cursorTarget ? "cursorTarget" : "focused";
  }

  get canLogInspectedElement() {
    const entry = this.selectedEntry;
    return entry
      ? hasElementHandle(entry.seq, this.inspectedElementField)
      : false;
  }

  get selectedEntry() {
    if (this.selectedSeq === undefined) {
      return this.latestEvent;
    }

    return timelineEntries().find(({ seq }) => seq === this.selectedSeq);
  }

  get factRows() {
    const region = this.inspectedRegion;
    if (region) {
      return [
        { label: i18n("dev_tools.a11y.facts.channel"), value: region.channel },
        {
          label: i18n("dev_tools.a11y.facts.tree_state"),
          value: i18n(
            region.outOfTree
              ? "dev_tools.a11y.regions.out_of_tree"
              : "dev_tools.a11y.regions.in_tree"
          ),
        },
        {
          label: i18n("dev_tools.a11y.facts.deliveries"),
          value: region.deliveries.toString(),
        },
        {
          label: i18n("dev_tools.a11y.facts.last_text"),
          value:
            region.lastText || i18n("dev_tools.a11y.regions.no_deliveries"),
        },
      ];
    }

    const snapshot = this.snapshot;
    if (!snapshot) {
      return [];
    }

    return presentRows([
      {
        label: i18n("dev_tools.a11y.facts.expanded"),
        value: snapshot.expanded,
      },
      { label: i18n("dev_tools.a11y.facts.owns"), value: snapshot.owns },
      {
        label: i18n("dev_tools.a11y.facts.cursor_state"),
        value:
          snapshot.cursorState === "absent" ? undefined : snapshot.cursorState,
      },
      {
        label: i18n("dev_tools.a11y.facts.cursor_container"),
        value:
          snapshot.cursorContainer === this.inspectorIdentity
            ? undefined
            : snapshot.cursorContainer,
      },
      {
        label: i18n("dev_tools.a11y.facts.position"),
        value:
          snapshot.cursorIndex === undefined
            ? snapshot.rowPosition
            : `${snapshot.cursorIndex + 1} / ${snapshot.cursorSize}`,
      },
      {
        label: i18n("dev_tools.a11y.facts.selected"),
        value: snapshot.rowSelected,
      },
      {
        label: i18n("dev_tools.a11y.facts.visual_cursor"),
        value: snapshot.visual,
      },
      {
        label: i18n("dev_tools.a11y.facts.cursors_agree"),
        value: AGREEMENT_LABELS[snapshot.agreement],
      },
      {
        label: i18n("dev_tools.a11y.facts.multiselectable"),
        value: snapshot.multiselectable,
      },
      {
        label: i18n("dev_tools.a11y.facts.selected_in_list"),
        value: snapshot.selectedCount?.toString(),
      },
      {
        label: i18n("dev_tools.a11y.facts.barriers"),
        value: snapshot.barriers,
      },
      {
        label: i18n("dev_tools.a11y.facts.measured_from"),
        value:
          snapshot.barrierSource === this.inspectorIdentity
            ? undefined
            : snapshot.barrierSource,
      },
      {
        label: i18n("dev_tools.a11y.facts.in_tree"),
        value: snapshot.inTree,
      },
      {
        label: i18n("dev_tools.a11y.facts.containment"),
        value:
          snapshot.containmentKind === "none"
            ? undefined
            : snapshot.inspectorContainment,
      },
    ]);
  }

  get selectedUtterance() {
    const entry =
      this.selectedSeq === undefined
        ? timelineEntries().at(-1)
        : this.selectedEntry;

    return entry ? utteranceFor([entry]) : undefined;
  }

  get snapshotFindings() {
    return this.selectedEntry?.findings ?? [];
  }

  get hasBrokenFinding() {
    return this.snapshotFindings.some(({ tier }) => tier === "broken");
  }

  get hasDetails() {
    return (
      Boolean(this.inspectorUtterance) ||
      this.snapshotFindings.length > 0 ||
      Boolean(this.inspectorIdentity) ||
      this.factRows.length > 0
    );
  }

  get inspectedRegionMuted() {
    return this.inspectedRegion?.muted ?? false;
  }

  get inspectedRegionKey() {
    return this.inspectedRegion?.key;
  }

  @action
  logInspectedElement() {
    const entry = this.selectedEntry;
    if (entry) {
      logElementHandle(entry.seq, this.inspectedElementField);
    }
  }

  @action
  toggleInspectedRegionMute() {
    if (this.inspectedRegionKey) {
      toggleLiveRegionMuted(this.inspectedRegionKey);
    }
  }

  @action
  toggleRegionMute(regionKey: string) {
    toggleLiveRegionMuted(regionKey);
  }

  @action
  setup(element: HTMLDivElement) {
    this.#document = element.ownerDocument;
    attachLiveRegions(element.ownerDocument);
    attachCapture(element.ownerDocument);

    this.#scroller = element.querySelector<HTMLElement>(
      ".dev-tools-a11y__scroller"
    )!;
    const content = element.querySelector<HTMLElement>(
      ".dev-tools-a11y__scroll-content"
    )!;

    this.#latestSeq = this.#currentLatestSeq();
    this.#scroller.addEventListener("scroll", this.#scrollListener);
    this.#resizeObserver = new ResizeObserver(() => {
      this.#resizeHandler = throttle(this, this.#updateDensityMap, 0, false);
    });
    this.#resizeObserver.observe(content);
    this.#resizeObserver.observe(this.#scroller);

    registerDestructor(this, () => {
      cancel(this.#rowsChangedHandler);
      cancel(this.#resizeHandler);
      cancel(this.#scrollHandler);
      cancel(this.#scrollToBottomHandler);
      this.#resizeObserver?.disconnect();
      this.#scroller?.removeEventListener("scroll", this.#scrollListener);
      detachCapture();
      pruneDetachedLiveRegions();
    });
  }

  @action
  updateFilter(event: Event) {
    this.filter = (event.target as HTMLInputElement).value;
  }

  @action
  clearFilter() {
    this.filter = "";
  }

  @action
  toggleProblems() {
    this.problemsOnly = !this.problemsOnly;
  }

  @action
  togglePaused() {
    setPaused(!isPaused());
  }

  @action
  onRegisterTestMenu(api: DMenuInstance) {
    this.#testMenu = api;
  }

  @action
  async runTestChannel(politeness: "polite" | "assertive") {
    await this.#testMenu?.close();
    this.a11y.announce("a11y inspector channel check", politeness);
  }

  @action
  async copy() {
    await navigator.clipboard.writeText(copyTrace());
    this.copied = true;
  }

  @action
  clear() {
    clearTimeline();
    this.copied = false;
    this.expandedRunIds = new Set();
    this.following = true;
    this.selectedSeq = undefined;
    this.selectedSubject = undefined;
    this.unseenCount = 0;
    this.#latestSeq = 0;
    this.#pendingArrivals = 0;
    cancel(this.#rowsChangedHandler);
    this.#rowsChangedHandler = undefined;
  }

  @action
  jumpToLatest() {
    this.following = true;
    this.unseenCount = 0;
    this.#latestSeq = this.#currentLatestSeq();
    this.#scheduleScrollToBottom();
  }

  @action
  selectRow(row: DisplayRow) {
    this.selectedSubject = row.subject;
    this.selectedSeq = row.selectSeq;
  }

  @action
  toggleRun(run: RunSubject, id: string, seq: number) {
    const expandedRunIds = new Set(this.expandedRunIds);
    if (expandedRunIds.has(id)) {
      expandedRunIds.delete(id);
    } else {
      expandedRunIds.add(id);
    }

    this.expandedRunIds = expandedRunIds;
    this.selectedSubject = onRunExpanded(run);
    this.selectedSeq = seq;
  }

  @action
  pickRunMember(run: RunSubject, seq: number) {
    this.selectedSubject = onRunMemberPicked(run, seq);
    this.selectedSeq = seq;
  }

  @action
  showTimeline() {
    this.view = "timeline";
  }

  @action
  showRegions() {
    this.view = "regions";
  }

  @action
  showSweep() {
    this.view = "sweep";
  }

  @action
  scanSweep() {
    this.sweepResult = sweepA11y(this.#document);
    this.expandedSweepFindingIds = new Set();
  }

  @action
  toggleSweepFinding(id: string) {
    const expanded = new Set(this.expandedSweepFindingIds);
    if (expanded.has(id)) {
      expanded.delete(id);
    } else {
      expanded.add(id);
    }
    this.expandedSweepFindingIds = expanded;
  }

  @action
  logSweepElement(handleId: number) {
    logSweepHandle(handleId);
  }

  #applyProjectedRowsChange() {
    const arrivals = this.#pendingArrivals;
    this.#pendingArrivals = 0;
    this.#rowsChangedHandler = undefined;

    if (this.following) {
      this.unseenCount = 0;
      this.#scheduleScrollToBottom();
    } else {
      this.unseenCount += arrivals;
    }
  }

  #projectedRowsChanged(rows: readonly Row[]) {
    const sequences = rows.flatMap(({ members }) => members);
    const latestSeq = Math.max(0, ...sequences);
    const arrivals = sequences.filter((seq) => seq > this.#latestSeq).length;
    this.#latestSeq = latestSeq;

    if (arrivals === 0) {
      return;
    }

    this.#pendingArrivals += arrivals;
    this.#rowsChangedHandler ??= next(this, this.#applyProjectedRowsChange);
  }

  #currentLatestSeq() {
    return timelineEntries().at(-1)?.seq ?? 0;
  }

  #historicalRegion(regionKey: string): DisplayRegion | undefined {
    const entries = timelineEntries().filter(
      (entry) => entry.regionKey === regionKey
    );
    let lifecycle: TimelineEntry | undefined;
    for (let index = entries.length - 1; index >= 0; index--) {
      if (/^#?.*?\s+\([^)]+\)$/.test(entries[index].detail)) {
        lifecycle = entries[index];
        break;
      }
    }
    if (!lifecycle) {
      return undefined;
    }

    const match = lifecycle.detail.match(/^#?(.*?)\s+\(([^)]+)\)$/);
    if (!match) {
      return undefined;
    }

    return {
      broken: [],
      channel: match[2],
      deliveries: 0,
      description: lifecycle.detail,
      fragile: [],
      key: regionKey,
      lastText: "",
      muted: mutedLiveRegionKeys().has(regionKey),
      noted: [],
      outOfTree: lifecycle.label === "live region left",
    };
  }

  #scheduleScrollCheck() {
    this.#scrollHandler = throttle(this, this.#updateFollowState, 0, false);
  }

  #scheduleScrollToBottom() {
    cancel(this.#scrollToBottomHandler);
    this.#scrollToBottomHandler = next(this, this.#scrollToBottom);
  }

  #scrollToBottom() {
    if (!this.#scroller) {
      return;
    }

    this.#scroller.scrollTop = this.#scroller.scrollHeight;
    this.#updateFollowState();
  }

  #updateFollowState() {
    if (!this.#scroller) {
      return;
    }

    this.#updateDensityMap();

    if (isAtBottom(this.#scroller)) {
      this.following = true;
      this.unseenCount = 0;
      this.#latestSeq = this.#currentLatestSeq();
    } else if (this.following) {
      this.following = false;
      this.#latestSeq = this.#currentLatestSeq();
    }
  }

  #updateDensityMap() {
    if (!this.#scroller) {
      return;
    }

    const { clientHeight, scrollHeight, scrollTop } = this.#scroller;
    this.hasOverflow = scrollHeight > clientHeight;
    this.viewportTop = scrollHeight ? (scrollTop / scrollHeight) * 100 : 0;
    this.viewportHeight = scrollHeight
      ? (clientHeight / scrollHeight) * 100
      : 100;
  }

  <template>
    <div
      class="dev-tools-a11y"
      data-dev-tools-trace-exclude=""
      {{didInsert this.setup}}
      ...attributes
    >
      <header class="dev-tools-panel__top-bar dev-tools-a11y__topbar">
        <div class="dev-tools-panel__heading">
          <span class="dev-tools-panel__title">
            {{i18n "dev_tools.a11y.title"}}
          </span>
          <div class="dev-tools-panel__chips">
            <span
              class={{dConcatClass
                "dev-tools-panel__chip dev-tools-a11y__chip"
                (if this.paused "--paused" "--capturing --success")
              }}
              title={{if
                this.paused
                (i18n "dev_tools.a11y.chip_paused_title")
                (i18n "dev_tools.a11y.chip_capturing_title")
              }}
            >
              <span
                class={{dConcatClass
                  "dev-tools-panel__live-dot"
                  (if this.paused "--paused")
                }}
              ></span>
              {{if
                this.paused
                (i18n "dev_tools.a11y.paused")
                (i18n "dev_tools.a11y.capturing")
              }}
            </span>
            <span
              class={{dConcatClass
                "dev-tools-panel__chip dev-tools-a11y__chip"
                "--regions"
                (if (eq this.liveRegionCount 0) "--critical")
              }}
              title={{this.liveRegionTitle}}
            >
              {{i18n "dev_tools.a11y.region_count" count=this.liveRegionCount}}
            </span>
          </div>
        </div>

        <div class="dev-tools-panel__action-group">
          <DMenu
            @identifier="dev-tools-a11y-test-channel"
            @icon="bullhorn"
            @modalForMobile={{false}}
            @title={{i18n "dev_tools.a11y.test_channel"}}
            @ariaLabel={{i18n "dev_tools.a11y.test_channel"}}
            @triggerClass="dev-tools-panel__action dev-tools-a11y__test-channel"
            @onRegisterApi={{this.onRegisterTestMenu}}
          >
            <:content>
              <div data-dev-tools-trace-exclude="">
                <DDropdownMenu as |dropdown|>
                  <dropdown.item>
                    <DButton
                      @label="dev_tools.a11y.test_channel_polite"
                      class="btn-transparent dev-tools-a11y__test-polite"
                      @action={{fn this.runTestChannel "polite"}}
                    />
                  </dropdown.item>
                  <dropdown.item>
                    <DButton
                      @label="dev_tools.a11y.test_channel_assertive"
                      class="btn-transparent dev-tools-a11y__test-assertive"
                      @action={{fn this.runTestChannel "assertive"}}
                    />
                  </dropdown.item>
                </DDropdownMenu>
              </div>
            </:content>
          </DMenu>
          <span class="dev-tools-panel__action-divider"></span>
          <button
            type="button"
            class="dev-tools-panel__action dev-tools-a11y__copy"
            title={{i18n "dev_tools.a11y.copy_trace"}}
            aria-label={{i18n "dev_tools.a11y.copy_trace"}}
            {{on "click" this.copy}}
          >
            {{dIcon (if this.copied "check" "far-clipboard")}}
          </button>
          <span class="dev-tools-panel__action-divider"></span>
          <button
            type="button"
            class="dev-tools-panel__action dev-tools-a11y__pause"
            aria-pressed={{if this.paused "true" "false"}}
            title={{if
              this.paused
              (i18n "dev_tools.a11y.resume")
              (i18n "dev_tools.a11y.pause")
            }}
            aria-label={{if
              this.paused
              (i18n "dev_tools.a11y.resume")
              (i18n "dev_tools.a11y.pause")
            }}
            {{on "click" this.togglePaused}}
          >
            {{dIcon (if this.paused "play" "pause")}}
          </button>
          <button
            type="button"
            class="dev-tools-panel__action dev-tools-a11y__clear"
            title={{i18n "dev_tools.a11y.clear"}}
            aria-label={{i18n "dev_tools.a11y.clear"}}
            {{on "click" this.clear}}
          >
            {{dIcon "ban"}}
          </button>
        </div>
      </header>

      {{#if (eq this.liveRegionCount 0)}}
        <div class="dev-tools-panel__warning dev-tools-a11y__warning">
          {{i18n "dev_tools.a11y.zero_regions_warning"}}
        </div>
      {{/if}}

      <div class="dev-tools-panel__toolbar dev-tools-a11y__toolbar">
        <DFilterInput
          @value={{this.filter}}
          @filterAction={{this.updateFilter}}
          @onClearInput={{this.clearFilter}}
          @icons={{hash left="magnifying-glass"}}
          placeholder={{i18n "dev_tools.a11y.filter_placeholder"}}
        />
        <button
          type="button"
          class={{dConcatClass
            "dev-tools-panel__action dev-tools-a11y__problems-toggle"
            (if this.problemsOnly "--active")
          }}
          aria-pressed={{if this.problemsOnly "true" "false"}}
          {{on "click" this.toggleProblems}}
        >
          {{i18n "dev_tools.a11y.problems_toggle"}}
        </button>
        <nav
          class="dev-tools-panel__views dev-tools-a11y__views"
          aria-label={{i18n "dev_tools.a11y.view"}}
        >
          <ul class="nav nav-pills">
            <li>
              <button
                type="button"
                class={{dConcatClass
                  "dev-tools-a11y__view --timeline"
                  (if (eq this.view "timeline") "active")
                }}
                aria-pressed={{if (eq this.view "timeline") "true" "false"}}
                {{on "click" this.showTimeline}}
              >
                {{i18n "dev_tools.a11y.views.timeline"}}
              </button>
            </li>
            <li>
              <button
                type="button"
                class={{dConcatClass
                  "dev-tools-a11y__view --regions"
                  (if (eq this.view "regions") "active")
                }}
                aria-pressed={{if (eq this.view "regions") "true" "false"}}
                {{on "click" this.showRegions}}
              >
                {{i18n "dev_tools.a11y.views.regions"}}
              </button>
            </li>
            <li>
              <button
                type="button"
                class={{dConcatClass
                  "dev-tools-a11y__view --sweep"
                  (if (eq this.view "sweep") "active")
                }}
                aria-pressed={{if (eq this.view "sweep") "true" "false"}}
                {{on "click" this.showSweep}}
              >
                {{i18n "dev_tools.a11y.views.sweep"}}
              </button>
            </li>
          </ul>
        </nav>
      </div>

      <div class="dev-tools-a11y__sweep" hidden={{not (eq this.view "sweep")}}>
        {{! The control and the scope line stay out of the scroller: expanding a rule
            used to carry both off the top, taking the primary action and the only
            evidence that the scan ran with them. }}
        <div class="dev-tools-a11y__sweep-header">
          <DButton
            class="btn-default dev-tools-a11y__sweep-scan"
            @label="dev_tools.a11y.sweep.scan"
            @action={{this.scanSweep}}
          />
          {{#if this.sweepResult}}
            <p class="dev-tools-a11y__sweep-scope">
              {{i18n
                "dev_tools.a11y.sweep.scope"
                regions=this.sweepResult.regions
                composites=this.sweepResult.composites
              }}
            </p>
          {{/if}}
        </div>
        <div class="dev-tools-a11y__sweep-body">
          {{#if this.sweepResult}}
            {{#if this.sweepResult.findings.length}}
              <ul class="dev-tools-a11y__sweep-findings">
                {{#each this.sweepFindings key="id" as |finding|}}
                  <li>
                    <button
                      type="button"
                      class={{dConcatClass
                        "dev-tools-a11y__sweep-row"
                        (if (eq finding.tier "broken") "--broken" "--fragile")
                      }}
                      aria-expanded={{if finding.expanded "true" "false"}}
                      {{on "click" (fn this.toggleSweepFinding finding.id)}}
                    >
                      <span class="dev-tools-a11y__sweep-rail"></span>
                      <span class="dev-tools-a11y__sweep-chevron">
                        {{dIcon
                          (if finding.expanded "chevron-down" "chevron-right")
                        }}
                      </span>
                      <span class="dev-tools-a11y__sweep-count">
                        {{finding.count}}
                      </span>
                      <span class="dev-tools-a11y__sweep-message">
                        {{i18n (findingKey finding.id) finding.params}}
                        <span class="dev-tools-a11y__sweep-rule">
                          {{finding.id}}
                        </span>
                      </span>
                    </button>
                    {{#if finding.expanded}}
                      <ul class="dev-tools-a11y__sweep-elements">
                        {{#each finding.elements key="handleId" as |element|}}
                          <li class="dev-tools-a11y__sweep-element">
                            <span>{{element.description}}</span>
                            <DButton
                              class="dev-tools-a11y__sweep-log"
                              @display="link"
                              @label="dev_tools.a11y.log_element"
                              @action={{fn
                                this.logSweepElement
                                element.handleId
                              }}
                            />
                          </li>
                        {{/each}}
                      </ul>
                    {{/if}}
                  </li>
                {{/each}}
              </ul>
            {{else}}
              <p class="dev-tools-panel__empty dev-tools-a11y__sweep-clean">
                {{i18n "dev_tools.a11y.sweep.clean"}}
              </p>
            {{/if}}
          {{/if}}
        </div>
      </div>

      <div
        class="dev-tools-a11y__regions"
        hidden={{not (eq this.view "regions")}}
      >
        {{#each this.regions key="key" as |region|}}
          <div
            class={{dConcatClass
              "dev-tools-a11y__region"
              (if region.broken.length "--broken")
              (if
                (and (not region.broken.length) region.fragile.length)
                "--fragile"
              )
              (if region.muted "--muted")
            }}
          >
            <span class="dev-tools-a11y__region-rail"></span>
            <span class="dev-tools-a11y__region-id">
              {{region.description}}
            </span>
            <span class="dev-tools-a11y__region-tags">
              <span class="dev-tools-a11y__region-tag">
                {{region.channel}}
              </span>
              {{#if region.outOfTree}}
                <span class="dev-tools-a11y__region-tag --out">
                  {{i18n "dev_tools.a11y.regions.out_of_tree"}}
                </span>
              {{/if}}
              {{#if region.muted}}
                <span class="dev-tools-a11y__region-tag --muted">
                  {{i18n "dev_tools.a11y.muted"}}
                </span>
              {{/if}}
            </span>
            <span class="dev-tools-a11y__region-last">
              {{#if region.lastText}}
                {{i18n
                  "dev_tools.a11y.regions.last_delivery"
                  text=region.lastText
                }}
              {{else}}
                {{i18n "dev_tools.a11y.regions.no_deliveries"}}
              {{/if}}
            </span>
            {{#each region.broken as |finding|}}
              <span class="dev-tools-a11y__region-message --broken">
                {{i18n (findingKey finding.id) finding.params}}
              </span>
            {{/each}}
            {{#each region.fragile as |finding|}}
              <span class="dev-tools-a11y__region-message --fragile">
                {{i18n (findingKey finding.id) finding.params}}
              </span>
            {{/each}}
            {{#each region.noted as |finding|}}
              <span class="dev-tools-a11y__region-message">
                {{i18n (findingKey finding.id) finding.params}}
              </span>
            {{/each}}
            <span class="dev-tools-a11y__region-count">
              {{i18n
                "dev_tools.a11y.regions.delivery_count"
                count=region.deliveries
              }}
            </span>
            <DButton
              class="btn-transparent dev-tools-a11y__mute"
              @translatedLabel={{i18n
                (if region.muted "dev_tools.a11y.unmute" "dev_tools.a11y.mute")
              }}
              @translatedAriaLabel={{i18n
                (if
                  region.muted
                  "dev_tools.a11y.unmute_region"
                  "dev_tools.a11y.mute_region"
                )
                region=region.key
              }}
              @ariaPressed={{region.muted}}
              @action={{fn this.toggleRegionMute region.key}}
            />
          </div>
        {{/each}}
      </div>

      <div
        class="dev-tools-a11y__scroll-shell"
        hidden={{not (eq this.view "timeline")}}
      >
        <div
          class="dev-tools-a11y__scroller"
          hidden={{not (eq this.view "timeline")}}
        >
          {{#unless this.following}}
            <div class="dev-tools-a11y__jump-wrap">
              <DButton
                class="btn-default dev-tools-a11y__jump"
                @translatedLabel={{i18n
                  "dev_tools.a11y.jump_to_latest"
                  count=this.unseenCount
                }}
                @action={{this.jumpToLatest}}
              />
            </div>
          {{/unless}}
          <div class="dev-tools-a11y__scroll-content">
            <ol class="dev-tools-a11y__timeline">
              {{#each this.entries key="id" as |row|}}
                <li>
                  {{#if row.quiet}}
                    {{#if (eq row.subject.kind "run")}}
                      <button
                        type="button"
                        class={{dConcatClass
                          "dev-tools-a11y__noise"
                          (if row.hasIntent "--intent")
                          (if row.hasDelivered "--delivered")
                          (if row.hasEvent "--event")
                          (if row.hasMeta "--meta")
                          (if row.selected "--selected")
                        }}
                        aria-expanded={{if row.expanded "true" "false"}}
                        aria-label={{i18n
                          (if
                            row.expanded
                            "dev_tools.a11y.collapse_run"
                            "dev_tools.a11y.expand_run"
                          )
                          name=(i18n
                            "dev_tools.a11y.noise_count"
                            count=row.count
                            name=row.noiseName
                          )
                        }}
                        aria-pressed={{if row.selected "true" "false"}}
                        {{on
                          "click"
                          (fn this.toggleRun row.subject row.id row.selectSeq)
                        }}
                      >
                        {{dIcon
                          (if row.expanded "chevron-down" "chevron-right")
                        }}
                        <span>
                          {{i18n
                            "dev_tools.a11y.noise_count"
                            count=row.count
                            name=row.noiseName
                          }}
                        </span>
                        <span class="dev-tools-a11y__noise-range">
                          {{row.seqLabel}}
                        </span>
                      </button>
                      {{#if row.expanded}}
                        <ol class="dev-tools-a11y__run-members">
                          {{#each row.memberRows key="id" as |member|}}
                            <li>
                              <EntryRow
                                @row={{member}}
                                @onSelect={{fn
                                  this.pickRunMember
                                  row.subject
                                  member.selectSeq
                                }}
                              />
                            </li>
                          {{/each}}
                        </ol>
                      {{/if}}
                    {{else}}
                      <button
                        type="button"
                        class={{dConcatClass
                          "dev-tools-a11y__noise"
                          (if row.hasIntent "--intent")
                          (if row.hasDelivered "--delivered")
                          (if row.hasEvent "--event")
                          (if row.hasMeta "--meta")
                          (if row.selected "--selected")
                        }}
                        aria-pressed={{if row.selected "true" "false"}}
                        {{on "click" (fn this.selectRow row)}}
                      >
                        <span>
                          {{i18n
                            "dev_tools.a11y.noise_count"
                            count=row.count
                            name=row.noiseName
                          }}
                        </span>
                        <span class="dev-tools-a11y__noise-range">
                          {{row.seqLabel}}
                        </span>
                      </button>
                    {{/if}}
                  {{else}}
                    <EntryRow
                      @row={{row}}
                      @onSelect={{fn this.selectRow row}}
                    />
                  {{/if}}
                </li>
                {{#if row.inspected}}
                  <li class="dev-tools-a11y__inspector --inline">
                    <Inspector
                      @canLogElement={{this.canLogInspectedElement}}
                      @facts={{this.factRows}}
                      @hasBrokenFinding={{this.hasBrokenFinding}}
                      @hasDetails={{this.hasDetails}}
                      @identity={{this.inspectorIdentity}}
                      @muted={{this.inspectedRegionMuted}}
                      @onLogElement={{this.logInspectedElement}}
                      @onToggleMute={{this.toggleInspectedRegionMute}}
                      @regionKey={{this.inspectedRegionKey}}
                      @snapshotFindings={{this.snapshotFindings}}
                      @utterance={{this.inspectorUtterance}}
                    />
                  </li>
                {{/if}}
              {{/each}}
              {{#unless this.hasInspectedRow}}
                <li class="dev-tools-a11y__inspector --inline">
                  <Inspector
                    @canLogElement={{this.canLogInspectedElement}}
                    @facts={{this.factRows}}
                    @hasBrokenFinding={{this.hasBrokenFinding}}
                    @hasDetails={{this.hasDetails}}
                    @identity={{this.inspectorIdentity}}
                    @muted={{this.inspectedRegionMuted}}
                    @onLogElement={{this.logInspectedElement}}
                    @onToggleMute={{this.toggleInspectedRegionMute}}
                    @regionKey={{this.inspectedRegionKey}}
                    @snapshotFindings={{this.snapshotFindings}}
                    @utterance={{this.inspectorUtterance}}
                  />
                </li>
              {{/unless}}
            </ol>
            {{#unless this.entries.length}}
              <p class="dev-tools-panel__empty dev-tools-a11y__empty">
                {{if
                  (or this.filter this.problemsOnly)
                  (i18n "dev_tools.a11y.no_matching_entries")
                  (i18n "dev_tools.a11y.empty_timeline")
                }}
              </p>
            {{/unless}}
          </div>
        </div>
        {{#if this.hasOverflow}}
          <div class="dev-tools-a11y__map" aria-hidden="true">
            {{#each this.densityMarks key="key" as |mark|}}
              <span
                class={{dConcatClass "dev-tools-a11y__map-mark" mark.modifier}}
                style={{mark.style}}
              ></span>
            {{/each}}
            <span
              class="dev-tools-a11y__map-viewport"
              style={{this.viewportStyle}}
            ></span>
          </div>
        {{/if}}
        <div class="dev-tools-a11y__inspector --aside">
          <Inspector
            @canLogElement={{this.canLogInspectedElement}}
            @facts={{this.factRows}}
            @hasBrokenFinding={{this.hasBrokenFinding}}
            @hasDetails={{this.hasDetails}}
            @identity={{this.inspectorIdentity}}
            @muted={{this.inspectedRegionMuted}}
            @onLogElement={{this.logInspectedElement}}
            @onToggleMute={{this.toggleInspectedRegionMute}}
            @regionKey={{this.inspectedRegionKey}}
            @snapshotFindings={{this.snapshotFindings}}
            @utterance={{this.inspectorUtterance}}
          />
        </div>
      </div>
    </div>
  </template>
}
