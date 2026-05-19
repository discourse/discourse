import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import TimelineScrubber from "discourse/components/timeline-scrubber";
import { and, gt } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class NestedTopicTimeline extends Component {
  @service header;
  @service nestedRootElements;

  @tracked activeGlobalIndex = null;
  @tracked latchedProgress = null;
  @tracked viewportWide = true;

  trackActiveRoot = modifier(() => {
    this.#unsubscribeRegistry = this.nestedRootElements.subscribe(
      this.#handleRegistryChange
    );

    this.#resizeHandler = () => this.#rebuildObserver();
    window.addEventListener("resize", this.#resizeHandler, { passive: true });

    this.#rebuildObserver();

    return () => {
      this.#unsubscribeRegistry?.();
      this.#unsubscribeRegistry = null;
      window.removeEventListener("resize", this.#resizeHandler);
      this.#resizeHandler = null;
      this.#observer?.disconnect();
      this.#observer = null;
      this.#aboveAnchor.clear();
    };
  });

  // Post-numbers currently above the anchor line. Updated only when an
  // IntersectionObserver entry fires — no per-scroll-frame work.
  #aboveAnchor = new Set();
  #observer = null;
  #unsubscribeRegistry = null;
  #resizeHandler = null;
  #mediaQuery = null;
  #onMediaChange = () => (this.viewportWide = this.#mediaQuery.matches);
  #handleRegistryChange = (type, postNumber, element) => {
    if (!this.#observer) {
      return;
    }
    if (type === "register") {
      this.#observer.observe(element);
    } else {
      this.#observer.unobserve(element);
      if (this.#aboveAnchor.delete(postNumber)) {
        this.#recomputeActive();
      }
    }
  };

  constructor() {
    super(...arguments);
    const layout = document.querySelector(".nested-topic-layout");
    const minWidth =
      parseInt(
        layout &&
          getComputedStyle(layout).getPropertyValue(
            "--nested-timeline-min-width"
          ),
        10
      ) || 925;
    this.#mediaQuery = matchMedia(`(min-width: ${minWidth}px)`);
    this.viewportWide = this.#mediaQuery.matches;
    this.#mediaQuery.addEventListener("change", this.#onMediaChange);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.#mediaQuery?.removeEventListener("change", this.#onMediaChange);
  }

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

  #rebuildObserver() {
    this.#observer?.disconnect();
    this.#aboveAnchor.clear();

    const anchorY = (this.header.headerOffset ?? 0) + 16;

    // rootMargin shrinks the top of the viewport by anchorY, so:
    //   - Threshold 1 fires when the element's top crosses anchorY
    //     (entering/leaving "fully below anchor")
    //   - Threshold 0 fires when the element's bottom crosses anchorY
    //     (entering/leaving "any part below anchor")
    // We use entry.boundingClientRect.top to determine which side of the
    // anchor the element is on — no rect read on the scroll path.
    this.#observer = new IntersectionObserver(
      (entries) => this.#handleEntries(entries, anchorY),
      {
        rootMargin: `-${anchorY}px 0px 0px 0px`,
        threshold: [0, 1],
      }
    );

    for (const el of this.nestedRootElements.elements()) {
      this.#observer.observe(el);
    }
  }

  #handleEntries(entries, anchorY) {
    let changed = false;
    for (const entry of entries) {
      const postNumber = this.nestedRootElements.postNumberFor(entry.target);
      if (postNumber == null) {
        continue;
      }
      const top = entry.boundingClientRect.top;
      // top < anchorY means the element's top edge has scrolled past the
      // anchor line, regardless of whether it's still partly visible.
      if (top < anchorY) {
        if (!this.#aboveAnchor.has(postNumber)) {
          this.#aboveAnchor.add(postNumber);
          changed = true;
        }
      } else if (this.#aboveAnchor.delete(postNumber)) {
        changed = true;
      }
    }
    if (changed) {
      this.#recomputeActive();
    }
  }

  // The active root is the bottom-most one currently above the anchor line —
  // i.e. the one the user is most likely reading. With rootNodes already in
  // DOM order, we iterate from the bottom and stop on the first match.
  #recomputeActive() {
    const pageSize = this.summary?.page_size;
    if (!pageSize) {
      return;
    }

    let activeDomIndex = 0;
    if (this.#aboveAnchor.size > 0) {
      const rootNodes = this.args.rootNodes ?? [];
      for (let i = rootNodes.length - 1; i >= 0; i--) {
        const postNumber = rootNodes[i]?.post?.post_number;
        if (postNumber != null && this.#aboveAnchor.has(postNumber)) {
          activeDomIndex = i;
          break;
        }
      }
    }

    const firstPage = this.args.firstLoadedPage ?? 0;
    // Pages after 0 contain only unpinned roots; pinned roots sit at the
    // top of total ordering but aren't re-rendered, so offset for them.
    const pinnedOffset =
      firstPage === 0 ? 0 : (this.summary?.pinned_count ?? 0);
    const globalIndex = pinnedOffset + firstPage * pageSize + activeDomIndex;

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
    {{#if (and this.viewportWide (gt this.total 0))}}
      <aside
        class="nested-topic-timeline"
        aria-label={{i18n "nested_replies.topic_timeline.aria_label"}}
        {{this.trackActiveRoot}}
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
