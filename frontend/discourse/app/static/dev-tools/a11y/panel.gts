import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { registerDestructor } from "@ember/destroyable";
import { concat, fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import type DMenuInstance from "discourse/float-kit/lib/d-menu-instance";
import A11y from "discourse/services/a11y";
import {
  type Finding,
  findingKey,
  isProblem,
} from "discourse/static/dev-tools/a11y/findings";
import type { CursorAgreement } from "discourse/static/dev-tools/a11y/inspect";
import {
  attachCapture,
  attachLiveRegions,
  clearTimeline,
  copyTrace,
  detachCapture,
  isPaused,
  pruneDetachedLiveRegions,
  setPaused,
  timelineEntries,
  type TimelineEntry,
  timelineEntryTrace,
  watchedLiveRegionCount,
  watchedLiveRegions,
} from "discourse/static/dev-tools/a11y/instrumentation";
import { eq, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import DFilterInput from "discourse/ui-kit/d-filter-input";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

type View = "timeline" | "inspector";

interface DisplayEntry {
  broken: Finding[];
  entry: TimelineEntry;
  fragile: Finding[];
  noted: Finding[];
  undelivered: boolean;
}

interface A11yPanelSignature {
  Element: HTMLDivElement;
}

interface InspectorRow {
  label: string;
  value: string;
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

export default class A11yPanel extends Component<A11yPanelSignature> {
  @service declare a11y: A11y;

  @tracked copied = false;
  @tracked filter = "";
  @tracked problemsOnly = false;
  @tracked selectedSeq?: number;
  @tracked view: View = "timeline";
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

  get entries(): DisplayEntry[] {
    const entries = timelineEntries();
    const filter = this.filter.trim().toLowerCase();

    return entries
      .map((entry) => {
        const undelivered = entry.findings.some(
          ({ id }) => id === "announce.undelivered"
        );

        return {
          broken: entry.findings.filter(
            (finding) =>
              finding.id !== "announce.undelivered" && isProblem(finding)
          ),
          entry,
          fragile: entry.findings.filter(
            (finding) => finding.tier === "fragile"
          ),
          noted: entry.findings.filter((finding) => finding.tier === "noted"),
          undelivered,
        };
      })
      .filter(({ broken, entry, undelivered: isUndelivered }) => {
        const matchesText =
          !filter || timelineEntryTrace(entry).toLowerCase().includes(filter);
        const matchesProblems =
          !this.problemsOnly || isUndelivered || broken.length > 0;
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
    return this.selectedEntry?.snapshot;
  }

  get selectedEntry() {
    if (this.selectedSeq === undefined) {
      return this.latestEvent;
    }

    return timelineEntries().find(({ seq }) => seq === this.selectedSeq);
  }

  get focusRows() {
    const snapshot = this.snapshot;
    if (!snapshot) {
      return [];
    }

    return presentRows([
      { label: "element", value: snapshot.focused },
      { label: "aria-label", value: snapshot.focusedLabel },
      { label: "description", value: snapshot.focusedDescription },
      { label: "aria-expanded", value: snapshot.expanded },
      { label: "aria-owns", value: snapshot.owns },
    ]);
  }

  get cursorRows() {
    const snapshot = this.snapshot;
    if (!snapshot) {
      return [];
    }

    return presentRows([
      { label: "state", value: snapshot.cursorState },
      { label: "target", value: snapshot.cursorTarget },
      { label: "container", value: snapshot.cursorContainer },
      {
        label: "position",
        value:
          snapshot.cursorIndex === undefined
            ? snapshot.rowPosition
            : `${snapshot.cursorIndex + 1} / ${snapshot.cursorSize}`,
      },
      { label: "aria-selected", value: snapshot.rowSelected },
      { label: "visual cursor", value: snapshot.visual },
      { label: "cursors agree", value: AGREEMENT_LABELS[snapshot.agreement] },
      { label: "aria-multiselectable", value: snapshot.multiselectable },
      { label: "selected in list", value: snapshot.selectedCount?.toString() },
    ]);
  }

  get deliveryRows() {
    const snapshot = this.snapshot;
    if (!snapshot) {
      return [];
    }

    return presentRows([
      {
        label: "barriers",
        value: snapshot.barriers,
      },
      {
        label: "measured from",
        value: snapshot.barrierSource,
      },
      {
        label: "in the tree",
        value: snapshot.inTree,
      },
      { label: "containment", value: snapshot.inspectorContainment },
      { label: "utterance", value: snapshot.utterance },
    ]);
  }

  get snapshotFindings() {
    return this.selectedEntry?.findings ?? [];
  }

  @action
  setup(element: HTMLDivElement) {
    attachLiveRegions(element.ownerDocument);
    attachCapture(element.ownerDocument);
    registerDestructor(this, () => {
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
    this.selectedSeq = undefined;
  }

  @action
  selectEntry(seq: number) {
    this.selectedSeq = seq;
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
                  "dev-tools-a11y__view --inspector"
                  (if (eq this.view "inspector") "active")
                }}
                aria-pressed={{if (eq this.view "inspector") "true" "false"}}
                {{on "click" this.showInspector}}
              >
                {{i18n "dev_tools.a11y.views.inspector"}}
              </button>
            </li>
          </ul>
        </nav>
      </div>

      {{#if this.entries.length}}
        <ol
          class="dev-tools-a11y__timeline"
          hidden={{eq this.view "inspector"}}
        >
          {{#each this.entries key="entry.seq" as |row|}}
            <li>
              <button
                type="button"
                class={{dConcatClass
                  "dev-tools-a11y__entry"
                  (concat "--" row.entry.kind)
                  (if (or row.undelivered row.broken.length) "--problem")
                  (if (eq this.selectedSeq row.entry.seq) "--selected")
                }}
                aria-pressed={{if
                  (eq this.selectedSeq row.entry.seq)
                  "true"
                  "false"
                }}
                {{on "click" (fn this.selectEntry row.entry.seq)}}
              >
                <span
                  class="dev-tools-a11y__entry-seq"
                >#{{row.entry.seq}}</span>
                <span
                  class="dev-tools-a11y__entry-kind"
                >{{row.entry.kind}}</span>
                <span class="dev-tools-a11y__entry-label">
                  {{row.entry.label}}
                  {{~#each row.entry.keys as |key|~}}
                    <kbd class="dev-tools-a11y__key">{{key}}</kbd>
                  {{~/each~}}
                </span>
                <span class="dev-tools-a11y__entry-detail">
                  {{row.entry.detail}}
                </span>
                {{#if row.undelivered}}
                  <span
                    class="dev-tools-panel__chip dev-tools-a11y__not-delivered"
                    title={{i18n "dev_tools.a11y.not_delivered_title"}}
                  >
                    {{i18n "dev_tools.a11y.not_delivered"}}
                  </span>
                {{/if}}
                {{#each row.broken as |finding|}}
                  <span
                    class="dev-tools-panel__chip --critical dev-tools-a11y__problem"
                  >{{i18n (findingKey finding.id) finding.params}}</span>
                {{/each}}
                {{#each row.fragile as |finding|}}
                  <span
                    class="dev-tools-panel__chip dev-tools-a11y__finding --fragile"
                  >{{i18n (findingKey finding.id) finding.params}}</span>
                {{/each}}
                {{#each row.noted as |finding|}}
                  <span class="dev-tools-a11y__finding --noted">
                    {{i18n (findingKey finding.id) finding.params}}
                  </span>
                {{/each}}
              </button>
            </li>
          {{/each}}
        </ol>
      {{else}}
        <p
          class="dev-tools-panel__empty dev-tools-a11y__empty"
          hidden={{eq this.view "inspector"}}
        >
          {{if
            (or this.filter this.problemsOnly)
            (i18n "dev_tools.a11y.no_matching_entries")
            (i18n "dev_tools.a11y.empty_timeline")
          }}
        </p>
      {{/if}}
      <div class="dev-tools-a11y__inspector" hidden={{eq this.view "timeline"}}>
        {{#if this.snapshot}}
          {{#if this.snapshotFindings.length}}
            <section class="dev-tools-a11y__group --problems">
              <h3 class="dev-tools-panel__section-heading">
                {{i18n "dev_tools.a11y.groups.problems"}}
              </h3>
              <div class="dev-tools-a11y__problem-strip">
                {{#each this.snapshotFindings as |finding|}}
                  {{#if (eq finding.tier "broken")}}
                    <span
                      class="dev-tools-panel__chip --critical dev-tools-a11y__problem"
                    >{{i18n (findingKey finding.id) finding.params}}</span>
                  {{else if (eq finding.tier "fragile")}}
                    <span
                      class="dev-tools-panel__chip dev-tools-a11y__finding --fragile"
                    >{{i18n (findingKey finding.id) finding.params}}</span>
                  {{else}}
                    <span class="dev-tools-a11y__finding --noted">
                      {{i18n (findingKey finding.id) finding.params}}
                    </span>
                  {{/if}}
                {{/each}}
              </div>
            </section>
          {{/if}}
          {{#if this.focusRows.length}}
            <section class="dev-tools-a11y__group">
              <h3 class="dev-tools-panel__section-heading">
                {{i18n "dev_tools.a11y.groups.focus"}}
              </h3>
              {{#each this.focusRows as |row|}}
                <dl><dt>{{row.label}}</dt><dd>{{row.value}}</dd></dl>
              {{/each}}
            </section>
          {{/if}}
          {{#if this.cursorRows.length}}
            <section class="dev-tools-a11y__group">
              <h3 class="dev-tools-panel__section-heading">
                {{i18n "dev_tools.a11y.groups.cursor"}}
              </h3>
              {{#each this.cursorRows as |row|}}
                <dl><dt>{{row.label}}</dt><dd>{{row.value}}</dd></dl>
              {{/each}}
            </section>
          {{/if}}
          {{#if this.deliveryRows.length}}
            <section class="dev-tools-a11y__group">
              <h3 class="dev-tools-panel__section-heading">
                {{i18n "dev_tools.a11y.groups.delivery"}}
              </h3>
              {{#each this.deliveryRows as |row|}}
                <dl><dt>{{row.label}}</dt><dd>{{row.value}}</dd></dl>
              {{/each}}
            </section>
          {{/if}}
        {{else}}
          <p class="dev-tools-panel__empty dev-tools-a11y__no-snapshot">
            {{i18n "dev_tools.a11y.no_snapshot"}}
          </p>
        {{/if}}
      </div>
    </div>
  </template>
}
