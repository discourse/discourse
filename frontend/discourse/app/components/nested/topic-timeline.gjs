import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { modifier } from "ember-modifier";
import TimelineScrubber from "discourse/components/timeline-scrubber";
import { eq, gt } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class NestedTopicTimeline extends Component {
  @service header;
  @service nestedRootElements;

  // activeGlobalIndex is the user's "where in the topic" position
  // across ALL roots (not just the loaded window). Normal mode looks up
  // activePostNumber in the summary entries; compact mode derives
  // `firstLoadedPage * page_size + indexInDom`. Drives scrubProgress so
  // the handle can't drift when the loaded window grows or shrinks.
  @tracked activePostNumber = null;
  @tracked activeGlobalIndex = null;

  trackViewport = modifier(() => {
    this.#scrollHandler = () => {
      if (this.#rafScheduled) {
        return;
      }
      this.#rafScheduled = true;
      requestAnimationFrame(() => {
        this.#rafScheduled = false;
        this.#updateActive();
      });
    };

    window.addEventListener("scroll", this.#scrollHandler, { passive: true });
    window.addEventListener("resize", this.#scrollHandler, { passive: true });

    requestAnimationFrame(() => this.#updateActive());

    return () => {
      window.removeEventListener("scroll", this.#scrollHandler);
      window.removeEventListener("resize", this.#scrollHandler);
      this.#scrollHandler = null;
    };
  });

  // Re-sync activeGlobalIndex whenever the loaded window shifts. After
  // jumpToRootPage / loadPreviousRoots the DOM mutates and we scroll,
  // but the resulting scroll event isn't always enough to trigger a
  // timely #updateActive — reading the arg here makes ember-modifier
  // re-run on every change, and we defer a frame so layout has settled.
  syncOnLoadedWindow = modifier((_el, [firstLoadedPage]) => {
    void firstLoadedPage;
    const handle = requestAnimationFrame(() => this.#updateActive());
    return () => cancelAnimationFrame(handle);
  });

  #rafScheduled = false;
  #scrollHandler = null;

  get summary() {
    return this.args.summary;
  }

  get total() {
    return this.summary?.total ?? 0;
  }

  get pageSize() {
    return this.summary?.page_size;
  }

  get pageCount() {
    if (this.summary?.page_count) {
      return this.summary.page_count;
    }
    if (!this.pageSize || this.total === 0) {
      return 0;
    }
    return Math.max(1, Math.ceil(this.total / this.pageSize));
  }

  get keyboardStep() {
    return this.total ? 1 / this.total : 0.05;
  }

  get ariaValueText() {
    return this.positionLabelAt(this.scrubProgress);
  }

  get entries() {
    return this.summary?.entries ?? null;
  }

  // True when the summary omits per-root entries (server returns only
  // totals once the root count exceeds ROOT_SUMMARY_THRESHOLD). In that
  // mode we render the scrubber without a density rail.
  get isCompact() {
    return !this.entries;
  }

  // Sort-dependent labels above/below the rail. The order of the rail
  // matches the current sort, so the labels tell the user what "up"
  // and "down" actually mean — see config/locales/client.en.yml for
  // the per-sort phrasing.
  get sortEndpoints() {
    const sort = this.args.sort || "top";
    return {
      start: i18n(`nested_replies.topic_timeline.sort_endpoints.${sort}.start`),
      end: i18n(`nested_replies.topic_timeline.sort_endpoints.${sort}.end`),
    };
  }

  // Log scale so a 100-reply root doesn't crush a 2-reply root to invisible.
  get maxDescendantCount() {
    if (!this.entries) {
      return 0;
    }
    let max = 0;
    for (const e of this.entries) {
      if (e.total_descendant_count > max) {
        max = e.total_descendant_count;
      }
    }
    return max;
  }

  densityFor(count) {
    if (!count || count <= 0) {
      return 0;
    }
    const max = this.maxDescendantCount;
    if (max <= 0) {
      return 0;
    }
    return Math.log(1 + count) / Math.log(1 + max);
  }

  get scrubProgress() {
    if (this.activeGlobalIndex == null || this.total <= 1) {
      return 0;
    }
    return Math.min(this.total - 1, this.activeGlobalIndex) / (this.total - 1);
  }

  // The readout below is driven by the progress value the primitive
  // yields from its slot — which is latch-aware. That way the readout
  // locks at the committed position during navigation in lockstep with
  // the handle (no flicker), and follows scroll afterward.
  @action
  indexAtProgress(progress) {
    if (this.total === 0) {
      return null;
    }
    return Math.min(this.total - 1, Math.floor(progress * this.total));
  }

  @action
  positionLabelAt(progress) {
    if (this.total === 0) {
      return null;
    }
    const idx = this.indexAtProgress(progress);
    if (idx == null) {
      return i18n("nested_replies.topic_timeline.position_total", {
        total: this.total,
      });
    }
    return i18n("nested_replies.topic_timeline.position", {
      current: idx + 1,
      total: this.total,
    });
  }

  @action
  entryAtProgress(progress) {
    if (!this.entries) {
      return null;
    }
    const idx = this.indexAtProgress(progress);
    if (idx == null) {
      return null;
    }
    return this.entries[idx] ?? null;
  }

  @action
  replyCountTextAt(progress) {
    const entry = this.entryAtProgress(progress);
    if (!entry) {
      return null;
    }
    return i18n("nested_replies.topic_timeline.replies", {
      count: entry.total_descendant_count,
    });
  }

  #updateActive() {
    const ordered = this.nestedRootElements.elementsInOrder();
    if (ordered.length === 0) {
      return;
    }

    const headerOffset = this.header.headerOffset ?? 0;
    const anchorY = headerOffset + 16;

    let bestDomIndex = -1;
    let bestTop = -Infinity;
    let bestPostNumber = null;

    for (let i = 0; i < ordered.length; i++) {
      const { top } = ordered[i];
      if (top <= anchorY && top > bestTop) {
        bestTop = top;
        bestDomIndex = i;
        bestPostNumber = ordered[i].postNumber;
      }
    }

    if (bestDomIndex < 0) {
      bestDomIndex = 0;
      bestPostNumber = ordered[0].postNumber;
    }

    let globalIndex = null;
    if (this.entries && bestPostNumber != null) {
      const idx = this.entries.findIndex(
        (e) => e.post_number === bestPostNumber
      );
      if (idx >= 0) {
        globalIndex = idx;
      }
    }
    if (globalIndex == null) {
      const pageSize = this.summary?.page_size;
      const firstPage = this.args.firstLoadedPage ?? 0;
      if (pageSize) {
        // On firstPage 0 the DOM contains pinned + first unpinned page,
        // so bestDomIndex already maps onto the total ordering. On later
        // pages the DOM has only unpinned roots, and the global position
        // is offset by N_pinned (which sit at the top of total ordering
        // but aren't re-rendered on those pages).
        const pinnedOffset =
          firstPage === 0 ? 0 : (this.summary?.pinned_count ?? 0);
        globalIndex = pinnedOffset + firstPage * pageSize + bestDomIndex;
      }
    }

    if (bestPostNumber != null && bestPostNumber !== this.activePostNumber) {
      this.activePostNumber = bestPostNumber;
    }
    if (globalIndex != null && globalIndex !== this.activeGlobalIndex) {
      this.activeGlobalIndex = globalIndex;
    }
  }

  @action
  segmentStyle(entry) {
    const intensity = this.densityFor(entry.total_descendant_count);
    return trustHTML(`--nested-timeline-density: ${intensity.toFixed(3)}`);
  }

  @action
  onCommit(progress) {
    this.#commitScrub(progress);
  }

  #commitScrub(progress) {
    const pageSize = this.pageSize;

    if (this.entries && this.entries.length > 0) {
      const idx = Math.min(
        this.entries.length - 1,
        Math.floor(progress * this.entries.length)
      );
      const target = this.entries[idx];
      if (this.#scrollToLoadedRoot(target.post_number)) {
        return;
      }
      if (pageSize && this.args.jumpToRootPage) {
        const targetPage = target.page ?? Math.floor(idx / pageSize);
        this.args.jumpToRootPage(targetPage, target.post_number);
        return;
      }
    }

    if (pageSize && this.total > 0 && this.args.jumpToRootPage) {
      const totalPages =
        this.pageCount || Math.max(1, Math.ceil(this.total / pageSize));
      const targetPage = Math.min(
        totalPages - 1,
        Math.floor(progress * totalPages)
      );
      this.args.jumpToRootPage(targetPage);
      return;
    }

    const max = Math.max(
      0,
      document.documentElement.scrollHeight - window.innerHeight
    );
    window.scrollTo({ top: progress * max, behavior: "auto" });
  }

  #scrollToLoadedRoot(postNumber) {
    const element = this.nestedRootElements.getElement(postNumber);
    if (!element) {
      return false;
    }
    const headerOffset = this.header.headerOffset ?? 0;
    const top =
      element.getBoundingClientRect().top + window.scrollY - headerOffset - 8;
    window.scrollTo({ top, behavior: "auto" });
    return true;
  }

  <template>
    {{#if (gt this.total 0)}}
      <aside
        class="nested-topic-timeline
          {{if this.isCompact 'nested-topic-timeline--compact'}}"
        aria-label={{i18n "nested_replies.topic_timeline.aria_label"}}
        {{this.trackViewport}}
        {{this.syncOnLoadedWindow @firstLoadedPage}}
      >
        <div
          class="nested-topic-timeline__endpoint nested-topic-timeline__endpoint--start"
        >
          {{this.sortEndpoints.start}}
        </div>

        <TimelineScrubber
          class="nested-topic-timeline__scrubber"
          @progress={{this.scrubProgress}}
          @ariaLabel={{i18n "nested_replies.topic_timeline.aria_label"}}
          @ariaValueText={{this.ariaValueText}}
          @keyboardStep={{this.keyboardStep}}
          @tolerance={{this.keyboardStep}}
          @onCommit={{this.onCommit}}
        >
          <:track>
            {{#unless this.isCompact}}
              <div class="nested-topic-timeline__density">
                {{#each this.entries key="post_number" as |entry|}}
                  <div
                    class="nested-topic-timeline__segment
                      {{if
                        (eq entry.post_number this.activePostNumber)
                        'is-active'
                      }}"
                    style={{this.segmentStyle entry}}
                  ></div>
                {{/each}}
              </div>
            {{/unless}}
          </:track>

          <:handle as |progress|>
            <div class="timeline-replies">
              {{this.positionLabelAt progress}}
            </div>
            {{#if (this.entryAtProgress progress)}}
              <div class="timeline-ago">
                {{this.replyCountTextAt progress}}
              </div>
            {{/if}}
          </:handle>
        </TimelineScrubber>

        <div
          class="nested-topic-timeline__endpoint nested-topic-timeline__endpoint--end"
        >
          {{this.sortEndpoints.end}}
        </div>
      </aside>
    {{/if}}
  </template>
}
