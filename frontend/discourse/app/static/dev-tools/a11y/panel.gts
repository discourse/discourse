import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { registerDestructor } from "@ember/destroyable";
import { concat, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import A11y from "discourse/services/a11y";
import {
  attachCapture,
  clearTimeline,
  copyTrace,
  detachCapture,
  observeLiveRegions,
  setPaused,
  timelineEntries,
  type TimelineEntry,
} from "discourse/static/dev-tools/a11y/instrumentation";
import devToolsState from "discourse/static/dev-tools/state";
import { eq, or } from "discourse/truth-helpers";
import DFilterInput from "discourse/ui-kit/d-filter-input";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

type View = "timeline" | "inspector";

interface DisplayEntry {
  entry: TimelineEntry;
  problems: string[];
  undelivered: boolean;
}

interface A11yPanelSignature {
  Element: HTMLDivElement;
}

const CORE_LIVE_REGION_SELECTORS = [
  "#a11y-announcements-polite",
  "#a11y-announcements-assertive",
] as const;

export function undeliveredIntentSequences(
  entries: readonly TimelineEntry[]
): ReadonlySet<number> {
  const undelivered = new Set<number>();

  for (let index = 0; index < entries.length; index++) {
    const entry = entries[index];
    if (entry.kind !== "intent") {
      continue;
    }

    let delivered = false;
    for (let next = index + 1; next < entries.length; next++) {
      if (entries[next].kind === "spoken") {
        delivered = true;
        break;
      }
      if (entries[next].kind === "intent") {
        break;
      }
    }

    if (!delivered) {
      undelivered.add(entry.seq);
    }
  }

  return undelivered;
}

function eventProblems(entry: TimelineEntry): string[] {
  if (entry.kind !== "event" || !entry.snapshot) {
    return [];
  }

  const { barriers, containment, cursor } = entry.snapshot;
  const problems: string[] = [];

  if (cursor.state === "dangling" || cursor.state === "not_item") {
    problems.push(`cursor: ${cursor.state}`);
  }
  if (containment.kind === "unclaimed") {
    problems.push("containment: unclaimed");
  }
  problems.push(...barriers.map((barrier) => `barrier: ${barrier}`));

  return problems;
}

function elementDescription(element: Element | null): string | undefined {
  if (!element) {
    return undefined;
  }

  const id = element.id ? `#${element.id}` : "";
  const role = element.getAttribute("role");
  return `${element.tagName.toLowerCase()}${id}${role ? `[role=${role}]` : ""}`;
}

export default class A11yPanel extends Component<A11yPanelSignature> {
  @service declare a11y: A11y;

  @tracked copied = false;
  @tracked filter = "";
  @tracked paused = devToolsState.getFlag("a11y", "paused") === true;
  @tracked problemsOnly = false;
  @tracked view: View = "timeline";

  get liveRegionCount() {
    const regions = new Set<Element>();

    for (const selector of CORE_LIVE_REGION_SELECTORS) {
      const region = document.querySelector(selector);
      if (region) {
        regions.add(region);
      }
    }
    for (const region of document.querySelectorAll("[aria-live]")) {
      regions.add(region);
    }

    return [...regions].filter(
      (region) => !region.closest(".dev-tools-toolbar")
    ).length;
  }

  get entries(): DisplayEntry[] {
    const entries = timelineEntries();
    const undelivered = undeliveredIntentSequences(entries);
    const filter = this.filter.trim().toLowerCase();

    return entries
      .map((entry) => ({
        entry,
        problems: eventProblems(entry),
        undelivered: undelivered.has(entry.seq),
      }))
      .filter(({ entry, problems, undelivered: isUndelivered }) => {
        const matchesText =
          !filter ||
          `${entry.label} ${entry.detail}`.toLowerCase().includes(filter);
        const matchesProblems =
          !this.problemsOnly || isUndelivered || problems.length > 0;
        return matchesText && matchesProblems;
      });
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
    return this.latestEvent?.snapshot;
  }

  get focusValue() {
    return elementDescription(this.snapshot?.focused ?? null);
  }

  get cursorRows() {
    const cursor = this.snapshot?.cursor;
    if (!cursor) {
      return [];
    }

    return [
      { label: "state", value: cursor.state },
      { label: "target", value: elementDescription(cursor.target) },
      { label: "container", value: elementDescription(cursor.container) },
      { label: "index", value: cursor.index?.toString() },
    ].filter((row): row is { label: string; value: string } =>
      Boolean(row.value)
    );
  }

  get deliveryRows() {
    const snapshot = this.snapshot;
    if (!snapshot) {
      return [];
    }

    const containment =
      snapshot.containment.kind === "claimed"
        ? `claimed via ${snapshot.containment.via.join(", ")}`
        : snapshot.containment.kind;

    return [
      {
        label: "barriers",
        value: snapshot.barriers.length
          ? snapshot.barriers.join(", ")
          : undefined,
      },
      { label: "containment", value: containment },
      { label: "utterance", value: snapshot.utterance },
    ].filter((row): row is { label: string; value: string } =>
      Boolean(row.value)
    );
  }

  get snapshotProblems() {
    return this.latestEvent ? eventProblems(this.latestEvent) : [];
  }

  @action
  setup(element: HTMLDivElement) {
    observeLiveRegions(element.ownerDocument);
    attachCapture(element.ownerDocument);
    registerDestructor(this, detachCapture);
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
    this.paused = !this.paused;
    setPaused(this.paused);
  }

  @action
  testChannel() {
    this.a11y.announce("a11y inspector channel check", "polite");
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
  }

  @action
  showTimeline() {
    this.view = "timeline";
  }

  @action
  showInspector() {
    this.view = "inspector";
  }

  <template>
    <div
      class="dev-tools-a11y"
      data-dev-tools-trace-exclude=""
      {{didInsert this.setup}}
      ...attributes
    >
      <div class="dev-tools-a11y__topbar">
        <span
          class={{dConcatClass
            "dev-tools-a11y__chip"
            (if this.paused "--paused" "--capturing")
          }}
        >
          <span class="dev-tools-a11y__live-dot"></span>
          {{if
            this.paused
            (i18n "dev_tools.a11y.paused")
            (i18n "dev_tools.a11y.capturing")
          }}
        </span>
        <span
          class={{dConcatClass
            "dev-tools-a11y__chip"
            "--regions"
            (if (eq this.liveRegionCount 0) "--critical")
          }}
        >
          {{i18n "dev_tools.a11y.region_count" count=this.liveRegionCount}}
        </span>
        <div class="dev-tools-a11y__actions">
          <button
            type="button"
            class="dev-tools-a11y__pause"
            aria-pressed={{if this.paused "true" "false"}}
            title={{if
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
            class="dev-tools-a11y__test-channel"
            title={{i18n "dev_tools.a11y.test_channel"}}
            {{on "click" this.testChannel}}
          >
            {{dIcon "bullhorn"}}
          </button>
          <button
            type="button"
            class="dev-tools-a11y__copy"
            title={{i18n "dev_tools.a11y.copy_trace"}}
            {{on "click" this.copy}}
          >
            {{dIcon (if this.copied "check" "far-clipboard")}}
          </button>
          <button
            type="button"
            class="dev-tools-a11y__clear"
            title={{i18n "dev_tools.a11y.clear"}}
            {{on "click" this.clear}}
          >
            {{dIcon "trash-can"}}
          </button>
        </div>
      </div>

      {{#if (eq this.liveRegionCount 0)}}
        <div class="dev-tools-a11y__warning">
          {{i18n "dev_tools.a11y.zero_regions_warning"}}
        </div>
      {{/if}}

      <div class="dev-tools-a11y__toolbar">
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
            "dev-tools-a11y__problems-toggle"
            (if this.problemsOnly "--active")
          }}
          aria-pressed={{if this.problemsOnly "true" "false"}}
          {{on "click" this.toggleProblems}}
        >
          {{i18n "dev_tools.a11y.problems_toggle"}}
        </button>
        <div class="dev-tools-a11y__views">
          <button
            type="button"
            class={{dConcatClass
              "dev-tools-a11y__view"
              "--timeline"
              (if (eq this.view "timeline") "--active")
            }}
            aria-pressed={{if (eq this.view "timeline") "true" "false"}}
            {{on "click" this.showTimeline}}
          >
            {{i18n "dev_tools.a11y.views.timeline"}}
          </button>
          <button
            type="button"
            class={{dConcatClass
              "dev-tools-a11y__view"
              "--inspector"
              (if (eq this.view "inspector") "--active")
            }}
            aria-pressed={{if (eq this.view "inspector") "true" "false"}}
            {{on "click" this.showInspector}}
          >
            {{i18n "dev_tools.a11y.views.inspector"}}
          </button>
        </div>
      </div>

      {{#if (eq this.view "timeline")}}
        {{#if this.entries.length}}
          <ol class="dev-tools-a11y__timeline">
            {{#each this.entries key="entry.seq" as |row|}}
              <li
                class={{dConcatClass
                  "dev-tools-a11y__entry"
                  (concat "--" row.entry.kind)
                  (if (or row.undelivered row.problems.length) "--problem")
                }}
              >
                <span
                  class="dev-tools-a11y__entry-seq"
                >#{{row.entry.seq}}</span>
                <span
                  class="dev-tools-a11y__entry-kind"
                >{{row.entry.kind}}</span>
                <span class="dev-tools-a11y__entry-detail">
                  {{row.entry.label}}
                  —
                  {{row.entry.detail}}
                </span>
                {{#if row.undelivered}}
                  <span
                    class="dev-tools-a11y__not-delivered"
                    title={{i18n "dev_tools.a11y.not_delivered_title"}}
                  >
                    {{i18n "dev_tools.a11y.not_delivered"}}
                  </span>
                {{/if}}
                {{#each row.problems as |problem|}}
                  <span class="dev-tools-a11y__problem">{{problem}}</span>
                {{/each}}
              </li>
            {{/each}}
          </ol>
        {{else}}
          <p class="dev-tools-a11y__empty">
            {{if
              (or this.filter this.problemsOnly)
              (i18n "dev_tools.a11y.no_matching_entries")
              (i18n "dev_tools.a11y.empty_timeline")
            }}
          </p>
        {{/if}}
      {{else}}
        <div class="dev-tools-a11y__inspector">
          {{#if this.snapshot}}
            {{#if this.snapshotProblems.length}}
              <section class="dev-tools-a11y__group --problems">
                <h3>{{i18n "dev_tools.a11y.groups.problems"}}</h3>
                <div class="dev-tools-a11y__problem-strip">
                  {{#each this.snapshotProblems as |problem|}}
                    <span class="dev-tools-a11y__problem">{{problem}}</span>
                  {{/each}}
                </div>
              </section>
            {{/if}}
            {{#if this.focusValue}}
              <section class="dev-tools-a11y__group">
                <h3>{{i18n "dev_tools.a11y.groups.focus"}}</h3>
                <dl><dt>element</dt><dd>{{this.focusValue}}</dd></dl>
              </section>
            {{/if}}
            {{#if this.cursorRows.length}}
              <section class="dev-tools-a11y__group">
                <h3>{{i18n "dev_tools.a11y.groups.cursor"}}</h3>
                {{#each this.cursorRows as |row|}}
                  <dl><dt>{{row.label}}</dt><dd>{{row.value}}</dd></dl>
                {{/each}}
              </section>
            {{/if}}
            {{#if this.deliveryRows.length}}
              <section class="dev-tools-a11y__group">
                <h3>{{i18n "dev_tools.a11y.groups.delivery"}}</h3>
                {{#each this.deliveryRows as |row|}}
                  <dl><dt>{{row.label}}</dt><dd>{{row.value}}</dd></dl>
                {{/each}}
              </section>
            {{/if}}
          {{else}}
            <p class="dev-tools-a11y__no-snapshot">
              {{i18n "dev_tools.a11y.no_snapshot"}}
            </p>
          {{/if}}
        </div>
      {{/if}}
    </div>
  </template>
}
