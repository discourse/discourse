import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import TimelineScrubber from "discourse/components/timeline-scrubber";
import { gt } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class NestedTopicTimeline extends Component {
  @service header;
  @service nestedRootElements;

  @tracked activeGlobalIndex = null;
  @tracked latchedProgress = null;

  trackViewport = modifier(() => {
    this.#scrollHandler = () => this.#scheduleUpdate();

    window.addEventListener("scroll", this.#scrollHandler, { passive: true });
    window.addEventListener("resize", this.#scrollHandler, { passive: true });

    this.#scheduleUpdate();

    return () => {
      window.removeEventListener("scroll", this.#scrollHandler);
      window.removeEventListener("resize", this.#scrollHandler);
      this.#scrollHandler = null;
      if (this.#rafHandle != null) {
        cancelAnimationFrame(this.#rafHandle);
        this.#rafHandle = null;
      }
    };
  });

  #rafHandle = null;
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
    return this.summary?.page_count ?? 0;
  }

  get keyboardStep() {
    return this.total ? 1 / this.total : 0.05;
  }

  get ariaValueText() {
    return this.positionLabelAt(this.effectiveProgress);
  }

  get sortEndpoints() {
    const sort = this.args.sort || "top";
    return {
      start: i18n(`nested_replies.topic_timeline.sort_endpoints.${sort}.start`),
      end: i18n(`nested_replies.topic_timeline.sort_endpoints.${sort}.end`),
    };
  }

  get scrubProgress() {
    if (this.activeGlobalIndex == null || this.total <= 1) {
      return 0;
    }
    return Math.min(this.total - 1, this.activeGlobalIndex) / (this.total - 1);
  }

  // Holds the handle at the just-committed position until jumpToRootPage
  // resolves and the post-jump scroll has propagated into activeGlobalIndex.
  // Without this the handle snaps back to the stale scrubProgress for a
  // visible flash.
  get effectiveProgress() {
    return this.latchedProgress ?? this.scrubProgress;
  }

  @action
  indexAtProgress(progress) {
    return Math.min(this.total - 1, Math.floor(progress * this.total));
  }

  @action
  positionLabelAt(progress) {
    return i18n("nested_replies.topic_timeline.position", {
      current: this.indexAtProgress(progress) + 1,
      total: this.total,
    });
  }

  #scheduleUpdate() {
    if (this.#rafHandle != null) {
      return;
    }
    this.#rafHandle = requestAnimationFrame(() => {
      this.#rafHandle = null;
      this.#updateActive();
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

    for (let i = 0; i < ordered.length; i++) {
      const { top } = ordered[i];
      if (top <= anchorY && top > bestTop) {
        bestTop = top;
        bestDomIndex = i;
      }
    }

    if (bestDomIndex < 0) {
      bestDomIndex = 0;
    }

    const pageSize = this.summary?.page_size;
    if (!pageSize) {
      return;
    }

    const firstPage = this.args.firstLoadedPage ?? 0;
    // Pages after 0 contain only unpinned roots; pinned roots sit at the
    // top of total ordering but aren't re-rendered, so offset for them.
    const pinnedOffset =
      firstPage === 0 ? 0 : (this.summary?.pinned_count ?? 0);
    const globalIndex = pinnedOffset + firstPage * pageSize + bestDomIndex;

    if (globalIndex !== this.activeGlobalIndex) {
      this.activeGlobalIndex = globalIndex;
    }
  }

  @action
  async onCommit(progress) {
    const pageSize = this.pageSize;
    if (!pageSize || this.total === 0 || !this.args.jumpToRootPage) {
      return;
    }

    // Page 0 holds pinned + first unpinned page; later pages hold only unpinned.
    const pinnedCount = this.summary?.pinned_count ?? 0;
    const targetIndex = this.indexAtProgress(progress);
    const unpinnedTargetIndex = Math.max(0, targetIndex - pinnedCount);
    const targetPage = Math.min(
      this.pageCount - 1,
      Math.floor(unpinnedTargetIndex / pageSize)
    );
    const targetOffset =
      targetPage === 0 ? targetIndex : unpinnedTargetIndex % pageSize;

    this.latchedProgress = progress;
    try {
      await this.args.jumpToRootPage(targetPage, null, targetOffset);
      await new Promise((r) =>
        requestAnimationFrame(() => requestAnimationFrame(r))
      );
    } finally {
      this.latchedProgress = null;
    }
  }

  @action
  jumpToStart() {
    return this.onCommit(0);
  }

  @action
  jumpToEnd() {
    return this.onCommit(1);
  }

  <template>
    {{#if (gt this.total 0)}}
      <aside
        class="nested-topic-timeline"
        aria-label={{i18n "nested_replies.topic_timeline.aria_label"}}
        {{this.trackViewport}}
      >
        <button
          type="button"
          class="nested-topic-timeline__endpoint nested-topic-timeline__endpoint--start"
          {{on "click" this.jumpToStart}}
        >
          {{this.sortEndpoints.start}}
        </button>

        <TimelineScrubber
          class="nested-topic-timeline__scrubber"
          @progress={{this.effectiveProgress}}
          @ariaLabel={{i18n "nested_replies.topic_timeline.aria_label"}}
          @ariaValueText={{this.ariaValueText}}
          @keyboardStep={{this.keyboardStep}}
          @onCommit={{this.onCommit}}
        >
          <:handle as |progress|>
            <div class="timeline-replies">
              {{this.positionLabelAt progress}}
            </div>
          </:handle>
        </TimelineScrubber>

        <button
          type="button"
          class="nested-topic-timeline__endpoint nested-topic-timeline__endpoint--end"
          {{on "click" this.jumpToEnd}}
        >
          {{this.sortEndpoints.end}}
        </button>
      </aside>
    {{/if}}
  </template>
}
