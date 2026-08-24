import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { modifier } from "ember-modifier";
import {
  SCROLLER_HEIGHT,
  timelineDate,
} from "discourse/components/topic-timeline/container";
import { eq } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dPointerDrag from "discourse/ui-kit/modifiers/d-pointer-drag";
import { i18n } from "discourse-i18n";

// Travel before a press on the handle becomes a scrub, so a click that wobbles
// does not move the reader.
const DRAG_THRESHOLD_PX = 3;

// Subtree size at which a branch mark reaches full length; growth is
// logarithmic so small differences stay visible at the low end.
const MARK_FULL_SCALE_DESCENDANTS = 100;
const MARK_MIN_WIDTH_EM = 0.75;
const MARK_MAX_WIDTH_EM = 2.25;

const COMPOSER_EVENTS = [
  "composer:opened",
  "composer:resized",
  "composer:closed",
  "composer:preview-toggled",
];

export function branchShape(node) {
  return shapeAtDepth(node, 0, new Set());
}

function shapeAtDepth(node, depth, visitedPostIds) {
  const postId = node?.post?.id;
  if (postId && visitedPostIds.has(postId)) {
    return { depth, continues: true };
  }

  const nextVisitedPostIds = new Set(visitedPostIds);
  if (postId) {
    nextVisitedPostIds.add(postId);
  }

  const descendants = node?.post?.total_descendant_count ?? 0;
  const directReplies = node?.post?.direct_reply_count ?? 0;
  const childShapes = (node?.children || []).map((child) =>
    shapeAtDepth(child, depth + 1, nextVisitedPostIds)
  );
  const loadedDepth = childShapes.reduce(
    (maximum, shape) => Math.max(maximum, shape.depth),
    depth
  );
  const guaranteedDepth =
    descendants > directReplies
      ? depth + 2
      : descendants > 0
        ? depth + 1
        : depth;
  const allDirectRepliesLoaded =
    directReplies > 0 && (node?.children?.length || 0) >= directReplies;
  const unseenNestedReplies =
    descendants > directReplies && !allDirectRepliesLoaded;

  return {
    depth: Math.max(loadedDepth, guaranteedDepth),
    continues:
      unseenNestedReplies || childShapes.some((shape) => shape.continues),
  };
}

export default class NestedTimeline extends Component {
  @service a11y;
  @service appEvents;
  @service composer;
  @service header;

  @tracked currentIndex = 0;
  @tracked percentage = 0;
  @tracked dragPercentage = 0;
  @tracked dragging = false;
  @tracked jumpStatus = null;
  @tracked scrollareaHeight = 300;

  setupTracking = modifier((element) => {
    this.#scrollareaElement = element;

    const onScrollOrResize = () => this.#scheduleUpdate();
    window.addEventListener("scroll", onScrollOrResize, { passive: true });
    window.addEventListener("resize", onScrollOrResize, { passive: true });
    for (const eventName of COMPOSER_EVENTS) {
      this.appEvents.on(eventName, onScrollOrResize);
    }
    // Schedule (rather than run) the initial measurement: #update reads and
    // writes tracked state, which is not allowed while the modifier installs
    // inside the render transaction.
    this.#scheduleUpdate();

    return () => {
      window.removeEventListener("scroll", onScrollOrResize);
      window.removeEventListener("resize", onScrollOrResize);
      for (const eventName of COMPOSER_EVENTS) {
        this.appEvents.off(eventName, onScrollOrResize);
      }
      if (this.#rafToken) {
        cancelAnimationFrame(this.#rafToken);
        this.#rafToken = null;
      }
      this.#scrollareaElement = null;
    };
  });
  #scrollareaElement = null;
  #rafToken = null;
  #dragStartPercentage = 0;
  #jumpToken = null;

  // Without a server total the axis still has to span the loaded window, which
  // starts at rootWindowStart rather than at zero once the reader has paged.
  get total() {
    return Math.max(
      this.args.rootCount ?? 0,
      (this.args.rootWindowStart ?? 0) + (this.args.rootNodes?.length ?? 0),
      1
    );
  }

  get activePercentage() {
    return this.dragging ? this.dragPercentage : this.percentage;
  }

  get displayIndex() {
    if (this.dragging) {
      return this.#indexForPercentage(this.dragPercentage);
    }

    return Math.min(this.currentIndex, this.total - 1);
  }

  get positionLabel() {
    return i18n("nested_replies.timeline.branches_short", {
      current: this.displayIndex + 1,
      total: this.total,
    });
  }

  get accessiblePositionLabel() {
    const position = i18n("nested_replies.timeline.branch_position", {
      current: this.displayIndex + 1,
      total: this.total,
    });

    return this.displayBranchSummary
      ? `${position}. ${this.displayBranchSummary}`
      : position;
  }

  get ariaValueNow() {
    return this.displayIndex + 1;
  }

  get displayDate() {
    const createdAt = this.displayNode?.post?.created_at;

    return createdAt ? timelineDate(new Date(createdAt)) : null;
  }

  get displayNode() {
    const localIndex = this.displayIndex - (this.args.rootWindowStart || 0);
    return this.args.rootNodes?.[localIndex];
  }

  // Three consumers read this per frame while scrubbing (the label, the
  // accessible description and the scroller body); walk the branch once.
  @cached
  get displayBranchSummary() {
    return this.#branchSummary(this.displayNode);
  }

  get scrollerStyle() {
    return trustHTML(
      `height: ${SCROLLER_HEIGHT}px; transform: translateY(${this.#trackHeight * this.activePercentage}px)`
    );
  }

  get #trackHeight() {
    return Math.max(this.scrollareaHeight - SCROLLER_HEIGHT, 0);
  }

  // One mark per loaded root that has replies, aligned with where the
  // scroller centre sits for that root. Length encodes subtree size; notches
  // encode the depth proven by loaded nodes and aggregate reply counts.
  //
  // Cached, and deliberately free of the active index: walking every loaded
  // root's subtree once per scrub frame is the expensive part, and which mark
  // is active is settled in the template instead.
  @cached
  get branchMarks() {
    const trackHeight = this.#trackHeight;
    const marks = [];

    (this.args.rootNodes || []).forEach((node, index) => {
      const descendants = node.post?.total_descendant_count ?? 0;
      if (descendants <= 0) {
        return;
      }

      const scale = Math.min(
        Math.log1p(descendants) / Math.log1p(MARK_FULL_SCALE_DESCENDANTS),
        1
      );
      const width =
        MARK_MIN_WIDTH_EM + (MARK_MAX_WIDTH_EM - MARK_MIN_WIDTH_EM) * scale;
      const shape = branchShape(node);
      const absoluteIndex = (this.args.rootWindowStart || 0) + index;
      const top =
        this.#percentageForPosition(absoluteIndex) * trackHeight +
        SCROLLER_HEIGHT / 2;

      marks.push({
        continues: shape.continues,
        depthIndicators: [...Array(Math.min(shape.depth, 4)).keys()],
        index: absoluteIndex,
        key: node.post.id,
        style: trustHTML(
          `top: ${top.toFixed(1)}px; width: ${width.toFixed(2)}em`
        ),
        title: this.#branchSummary(node, shape),
      });
    });

    return marks;
  }

  get hasPartialMetadata() {
    return (
      (this.args.rootWindowStart || 0) > 0 ||
      (this.args.rootNodes?.length || 0) < this.total
    );
  }

  // Measured against the track, like the marks it brackets: the scrollarea is
  // taller than the travel available to the handle, so spanning the full height
  // would leave the band off the marks everywhere but the middle of the axis.
  get loadedWindowStyle() {
    const trackHeight = this.#trackHeight;
    const start = Math.max(this.args.rootWindowStart || 0, 0);
    const count = Math.max(
      0,
      Math.min(this.args.rootNodes?.length || 0, this.total - start)
    );
    const top =
      this.#percentageForPosition(start) * trackHeight + SCROLLER_HEIGHT / 2;
    const height = Math.max((count / this.total) * trackHeight, 2);

    return trustHTML(
      `top: ${top.toFixed(1)}px; height: ${height.toFixed(1)}px`
    );
  }

  get metadataRangeLabel() {
    if (!this.hasPartialMetadata || !this.args.rootNodes?.length) {
      return null;
    }

    const start = (this.args.rootWindowStart || 0) + 1;
    const end = Math.min(
      (this.args.rootWindowStart || 0) + this.args.rootNodes.length,
      this.total
    );

    return i18n("nested_replies.timeline.details_range", { start, end });
  }

  @action
  refreshPosition() {
    this.#scheduleUpdate();
  }

  @action
  onDragStart() {
    this.#scrollareaElement?.focus();
    this.dragging = true;
    this.#dragStartPercentage = this.percentage;
    this.dragPercentage = this.percentage;
  }

  @action
  onDrag(_event, info) {
    this.#setDragPercentage(this.#percentageForDrag(info));
  }

  @action
  onDragEnd(_event, info) {
    this.dragging = false;
    // A press that never travelled is a click on the handle, which already
    // sits where it would jump to.
    if (info.moved) {
      void this.#commitPercentage(this.#percentageForDrag(info));
    }
  }

  @action
  onDragCancel() {
    // The gesture was taken away (touch turned into a scroll, the OS stepped
    // in). Drop the preview and let the viewport put the handle back.
    this.dragging = false;
    this.dragPercentage = this.percentage;
    this.#scheduleUpdate();
  }

  @action
  jumpToPointer(event) {
    if (event.target.closest(".nested-timeline__scroller")) {
      return;
    }

    void this.#commitPercentage(this.#percentageFromClick(event));
  }

  @action
  handleKeydown(event) {
    const pageSize = Math.max(Math.floor(this.total / 10), 1);
    let targetIndex;

    // The first branch sits at the top of the track, so the keys follow the
    // direction the handle travels rather than the "up increases" convention
    // of a slider whose maximum is at the top.
    switch (event.key) {
      case "ArrowDown":
      case "ArrowRight":
        targetIndex = this.displayIndex + 1;
        break;
      case "ArrowUp":
      case "ArrowLeft":
        targetIndex = this.displayIndex - 1;
        break;
      case "PageDown":
        targetIndex = this.displayIndex + pageSize;
        break;
      case "PageUp":
        targetIndex = this.displayIndex - pageSize;
        break;
      case "Home":
        targetIndex = 0;
        break;
      case "End":
        targetIndex = this.total - 1;
        break;
      default:
        return;
    }

    event.preventDefault();
    event.stopPropagation();
    targetIndex = Math.max(0, Math.min(targetIndex, this.total - 1));
    void this.#commitIndex(targetIndex, this.#percentageForIndex(targetIndex));
  }

  #setDragPercentage(percentage) {
    if (percentage !== this.dragPercentage) {
      this.dragPercentage = percentage;
    }
  }

  #commitPercentage(percentage) {
    const index = this.#indexForPercentage(percentage);
    return this.#commitIndex(index, percentage);
  }

  async #commitIndex(index, percentage) {
    const jumpToken = (this.#jumpToken = {});
    this.jumpStatus = null;
    this.percentage = percentage;
    this.currentIndex = index;

    const result = await this.args.jumpToRoot?.(index);
    if (
      !result ||
      this.isDestroying ||
      this.isDestroyed ||
      this.#jumpToken !== jumpToken
    ) {
      return;
    }

    if (!result.reached) {
      this.currentIndex = result.index;
      this.percentage = this.#percentageForIndex(result.index);
      this.jumpStatus = i18n("nested_replies.timeline.jump_incomplete", {
        current: result.index + 1,
        total: this.total,
      });
      this.a11y.announce(this.jumpStatus, "polite");
    }
  }

  #indexForPercentage(percentage) {
    return Math.min(Math.floor(percentage * this.total), this.total - 1);
  }

  #percentageForIndex(index) {
    return index === this.total - 1 ? 1 : this.#percentageForPosition(index);
  }

  #percentageForPosition(index, fraction = 0) {
    return this.#clamp(
      (Math.max(0, Math.min(index, this.total - 1)) + this.#clamp(fraction)) /
        this.total
    );
  }

  // The gesture reports travel from where the press landed, so the handle
  // moves with the pointer without measuring either against the track.
  #percentageForDrag(info) {
    const trackHeight = this.#trackHeight;
    if (trackHeight <= 0) {
      return this.dragPercentage;
    }

    return this.#clamp(this.#dragStartPercentage + info.delta.y / trackHeight);
  }

  #percentageFromClick(event) {
    const element = this.#scrollareaElement;
    const trackHeight = this.#trackHeight;
    if (!element || trackHeight <= 0 || event.clientY == null) {
      return this.percentage;
    }

    const offset =
      event.clientY - element.getBoundingClientRect().top - SCROLLER_HEIGHT / 2;

    return this.#clamp(offset / trackHeight);
  }

  #scheduleUpdate() {
    if (this.#rafToken) {
      return;
    }

    this.#rafToken = requestAnimationFrame(() => {
      this.#rafToken = null;
      this.#update();
    });
  }

  #update() {
    if (this.isDestroying || this.isDestroyed || !this.#scrollareaElement) {
      return;
    }

    const measuredHeight =
      this.#scrollareaElement.offsetHeight || this.scrollareaHeight;
    if (measuredHeight !== this.scrollareaHeight) {
      this.scrollareaHeight = measuredHeight;
    }

    if (this.dragging) {
      return;
    }

    const position = this.#positionFromViewport();
    if (!position) {
      return;
    }

    const absoluteIndex = (this.args.rootWindowStart || 0) + position.index;
    if (absoluteIndex !== this.currentIndex) {
      this.currentIndex = absoluteIndex;
    }

    const percentage = this.#percentageForPosition(
      absoluteIndex,
      position.fraction
    );
    if (Math.abs(percentage - this.percentage) > 0.0005) {
      this.percentage = percentage;
    }
  }

  // Mirrors the flat timeline's eyeline: a reference line that starts at the
  // header when the roots enter the viewport and slides down to the (composer
  // aware) viewport bottom as the roots list scrolls out, so the position
  // covers the full 0..1 range without suggested topics or other content
  // below the roots skewing the denominator.
  #positionFromViewport() {
    const rootsContainer = document.querySelector(
      ".nested-view:not(.nested-context-view) .nested-view__roots-window"
    );
    if (!rootsContainer) {
      return null;
    }

    const rootElements = rootsContainer.querySelectorAll(
      ":scope > .nested-post"
    );
    if (rootElements.length === 0) {
      return null;
    }

    const headerOffset = this.header.headerOffset || 0;
    const composerHeight = this.composer.isPreviewVisible
      ? document.getElementById("reply-control")?.offsetHeight || 0
      : 0;
    const viewportBottom = window.innerHeight - composerHeight;

    const rootsRect = rootsContainer.getBoundingClientRect();
    const startScrollY = rootsRect.top + window.scrollY - headerOffset;
    const endScrollY = rootsRect.bottom + window.scrollY - viewportBottom;
    const denominator = endScrollY - startScrollY;
    const progress =
      denominator > 0
        ? this.#clamp((window.scrollY - startScrollY) / denominator)
        : 0;
    const eyeline = headerOffset + (viewportBottom - headerOffset) * progress;

    // Roots are laid out top-to-bottom, so binary-search for the last root
    // starting at or above the eyeline instead of measuring every root.
    let lo = 0;
    let hi = rootElements.length - 1;
    let index = 0;
    let indexRect = null;

    while (lo <= hi) {
      const mid = Math.floor((lo + hi) / 2);
      const rect = rootElements[mid].getBoundingClientRect();
      if (rect.top <= eyeline) {
        index = mid;
        indexRect = rect;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }

    const fraction =
      indexRect && indexRect.height > 0
        ? this.#clamp((eyeline - indexRect.top) / indexRect.height)
        : 0;

    return { index, fraction };
  }

  #clamp(value) {
    return Math.max(0, Math.min(value, 1));
  }

  #branchSummary(node, precomputedShape = null) {
    const descendants = node?.post?.total_descendant_count ?? 0;
    if (descendants <= 0) {
      return null;
    }

    const shape = precomputedShape ?? branchShape(node);
    const replies = i18n("nested_replies.timeline.reply_count", {
      count: descendants,
    });
    const depth = i18n(
      shape.continues
        ? "nested_replies.timeline.depth_lower_bound"
        : "nested_replies.timeline.depth",
      { count: shape.depth }
    );

    return i18n("nested_replies.timeline.branch_summary", {
      replies,
      depth,
    });
  }

  <template>
    <div class="nested-timeline" ...attributes>
      <div class="nested-timeline__inner">
        <div
          class={{dConcatClass
            "nested-timeline__scrollarea"
            (if @loadingMore "is-loading")
          }}
          role="slider"
          tabindex="0"
          aria-label={{i18n "nested_replies.timeline.slider_label"}}
          aria-orientation="vertical"
          aria-valuemin="1"
          aria-valuemax={{this.total}}
          aria-valuenow={{this.ariaValueNow}}
          aria-valuetext={{this.accessiblePositionLabel}}
          aria-busy={{if @loadingMore "true" "false"}}
          {{this.setupTracking}}
          {{didUpdate this.refreshPosition @rootNodes @rootCount}}
          {{on "click" this.jumpToPointer}}
          {{on "keydown" this.handleKeydown}}
        >
          <div class="nested-timeline__map" aria-hidden="true">
            {{#if this.hasPartialMetadata}}
              <span
                class="nested-timeline__loaded-window"
                style={{this.loadedWindowStyle}}
              ></span>
            {{/if}}
            {{#each this.branchMarks key="key" as |mark|}}
              <div
                class={{dConcatClass
                  "nested-timeline__mark"
                  (if (eq mark.index this.displayIndex) "is-active")
                }}
                style={{mark.style}}
                title={{mark.title}}
              >
                <span class="nested-timeline__mark-amount"></span>
                <span class="nested-timeline__mark-depth">
                  {{#each mark.depthIndicators as |depth|}}
                    <span
                      class="nested-timeline__mark-notch"
                      data-depth={{depth}}
                    ></span>
                  {{/each}}
                  {{#if mark.continues}}
                    <span class="nested-timeline__mark-continuation">+</span>
                  {{/if}}
                </span>
              </div>
            {{/each}}
          </div>

          <div
            class="nested-timeline__scroller"
            style={{this.scrollerStyle}}
            {{dPointerDrag
              onDragStart=this.onDragStart
              onDrag=this.onDrag
              onDragEnd=this.onDragEnd
              onDragCancel=this.onDragCancel
              draggingClass="is-dragging"
              bodyClass="dragging"
              threshold=DRAG_THRESHOLD_PX
            }}
          >
            <div class="nested-timeline__handle"></div>
            <div class="nested-timeline__scroller-content">
              <div
                class="nested-timeline__position"
              >{{this.positionLabel}}</div>
              {{#if this.displayDate}}
                <div class="nested-timeline__date">{{this.displayDate}}</div>
              {{/if}}
              {{#if this.displayBranchSummary}}
                <div class="nested-timeline__branch-summary">
                  {{this.displayBranchSummary}}
                </div>
              {{/if}}
            </div>
          </div>
        </div>
        <div class="nested-timeline__legend">
          <div class="nested-timeline__legend-item">
            <svg
              class="nested-timeline__legend-symbol --loaded"
              aria-hidden="true"
              viewBox="0 0 36 12"
              width="2.25em"
              height="0.75em"
            >
              <rect x="24" y="1" width="12" height="10" rx="2"></rect>
            </svg>
            {{i18n "nested_replies.timeline.legend.loaded"}}
          </div>
          <div class="nested-timeline__legend-item">
            <svg
              class="nested-timeline__legend-symbol --amount"
              aria-hidden="true"
              viewBox="0 0 36 12"
              width="2.25em"
              height="0.75em"
            >
              <path
                d="M0 6H36"
                fill="none"
                pathLength="36"
                stroke="currentColor"
                stroke-linecap="round"
                stroke-width="2"
              ></path>
            </svg>
            {{i18n "nested_replies.timeline.legend.amount"}}
          </div>
          <div class="nested-timeline__legend-item">
            <svg
              class="nested-timeline__legend-symbol --depth"
              aria-hidden="true"
              viewBox="0 0 36 12"
              width="2.25em"
              height="0.75em"
            >
              <path
                d="M24 1V11M30 1V11M36 1V11"
                fill="none"
                stroke="currentColor"
                stroke-linecap="round"
                stroke-width="2"
              ></path>
            </svg>
            {{i18n "nested_replies.timeline.legend.depth"}}
          </div>
          <div class="nested-timeline__legend-item">
            <svg
              class="nested-timeline__legend-symbol --continuation"
              aria-hidden="true"
              viewBox="0 0 36 12"
              width="2.25em"
              height="0.75em"
            >
              <path
                d="M24 6H36M30 0V12"
                fill="none"
                stroke="currentColor"
                stroke-linecap="round"
                stroke-width="2"
              ></path>
            </svg>
            {{i18n "nested_replies.timeline.legend.continuation"}}
          </div>
        </div>
        {{#if this.metadataRangeLabel}}
          <div class="nested-timeline__metadata-range">
            {{this.metadataRangeLabel}}
          </div>
        {{/if}}
        {{#if this.jumpStatus}}
          <div class="nested-timeline__status">{{this.jumpStatus}}</div>
        {{/if}}
      </div>
    </div>
  </template>
}
