import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import { modifier } from "ember-modifier";

// Vertical scrubber rail shared between the flat-view and nested-view
// topic timelines. Owns the rail + scroller (pill) DOM, pointer-event
// drag (with capture, so dragging off the rail still tracks), and
// defer-until-release commit semantics.
//
// Args:
//   @progress      Number in [0, 1]. Where the scroller sits when the
//                  user is not dragging.
//   @ariaLabel     Accessible name for the slider.
//   @ariaValueText Optional accessible description of the current position.
//   @onDrag        Optional. Called with the new progress on every
//                  pointer move while dragging.
//   @onCommit      Called once with the final progress on pointer up.
//   @onDragStart / @onDragEnd  Optional lifecycle hooks.
//   @interactiveTrack Optional. Allows interactive controls in <:track>;
//                  nested's density rail leaves this unset.
//
// Slots:
//   <:track as |progress dragging|>
//                  Content rendered inside the rail track behind the
//                  scroller (density segments, last-read marker, etc.).
//                  Yielded `progress` is the latch-aware value driving
//                  the handle; `dragging` is true while the user holds
//                  the pointer down.
//   <:handle as |progress dragging|>
//                  Content rendered inside the scroller pill (labels,
//                  dates, buttons). Same yielded args.
//
// The DOM matches the classic topic-timeline class names so existing
// CSS / themes / plugins targeting `.timeline-scrollarea`,
// `.timeline-scroller`, `.timeline-handle`, etc. continue to work.
// Visual height of the scroller pill. Authoritative for both the
// scrubber primitive (drag math fallback) and the flat-view container
// (last-read marker positioning). The CSS variable
// `--timeline-scroller-height` mirrors this value so themes can scale
// the pill — keep them in sync if you change it.
export const SCROLLER_HEIGHT = 50;

// How long the committed-progress latch holds before auto-releasing.
// Picks up the slack on slow networks where @progress hasn't caught up
// yet — long enough for typical commit→navigate→resync cycles, short
// enough that a truly stuck latch is briefly noticeable rather than
// permanent.
const LATCH_TIMEOUT_MS = 2000;

export default class TimelineScrubber extends Component {
  @tracked dragging = false;
  @tracked dragProgress = 0;

  // Between commit and the next @progress update the handle would
  // otherwise snap back to the stale @progress for one render (visible
  // as a jump on slow networks). We hold the committed value in
  // latchedProgress until either:
  //   (a) @progress catches up — same value or within tolerance — released
  //       by the watchProgress modifier below.
  //   (b) LATCH_TIMEOUT_MS elapses — released via the timer as a safety
  //       net for cases where the commit didn't land where we asked.
  @tracked latchedProgress = null;
  registerRail = modifier((el) => {
    this.#railEl = el;
    return () => {
      this.#railEl = null;
    };
  });
  registerScroller = modifier((el) => {
    this.#scrollerEl = el;
    return () => {
      this.#scrollerEl = null;
    };
  });

  // Releases the latch when @progress catches up. Runs after every
  // render with the current @progress value, so we have a tracked-clean
  // place to clear latchedProgress without writing from a getter.
  // Without this the handle would hang at the committed position after
  // page snap (commit at 0.50 lands at 0.48, latch never releases).
  //
  // We defer the actual clear via a microtask: the modifier read
  // latchedProgress in this same render pass (via this.progress in the
  // template), so writing it synchronously would trip Glimmer's
  // auto-tracking backtracking check. A microtask runs after this render
  // finishes but before the next paint, so the next @progress value
  // takes effect immediately on the next render.
  watchProgress = modifier((_el, [progress]) => {
    if (this.latchedProgress == null || this.dragging) {
      return;
    }
    if (Math.abs((progress ?? 0) - this.latchedProgress) <= this.tolerance) {
      const snapshot = this.latchedProgress;
      Promise.resolve().then(() => {
        if (this.latchedProgress === snapshot) {
          this.#clearLatch();
        }
      });
    }
  });

  #latchTimeout = null;
  #railEl = null;
  #scrollerEl = null;
  #dragOffset = 0;

  willDestroy() {
    super.willDestroy(...arguments);
    if (this.#latchTimeout) {
      clearTimeout(this.#latchTimeout);
      this.#latchTimeout = null;
    }
  }

  get progress() {
    if (this.dragging) {
      return this.dragProgress;
    }
    if (this.latchedProgress != null) {
      return this.latchedProgress;
    }
    return this.args.progress ?? 0;
  }

  #clearLatch() {
    if (this.#latchTimeout) {
      clearTimeout(this.#latchTimeout);
      this.#latchTimeout = null;
    }
    this.latchedProgress = null;
  }

  get railStyle() {
    // Drive the scroller's top via a CSS custom property. Positioning
    // math (handle never overflows the rail) is done in CSS using
    // --timeline-scroller-height for the travel-range subtraction.
    // @height (optional) sets the rail height inline — for consumers
    // that compute it dynamically and would otherwise need a wrapper.
    let css = `--scrubber-progress: ${this.progress.toFixed(4)}`;
    if (this.args.height != null) {
      css += `; height: ${this.args.height}px`;
    }
    return trustHTML(css);
  }

  get keyboardStep() {
    return this.args.keyboardStep ?? 0.05;
  }

  get tolerance() {
    // Clamp to a small floor so a 1-item topic doesn't end up with
    // tolerance 1.0 (which would mean "always release immediately").
    return Math.max(0.001, this.args.tolerance ?? 0.05);
  }

  #progressFromClientY(clientY) {
    if (!this.#railEl) {
      return 0;
    }
    const rect = this.#railEl.getBoundingClientRect();
    const scrollerHeight =
      this.#scrollerEl?.getBoundingClientRect().height || SCROLLER_HEIGHT;
    const travel = Math.max(1, rect.height - scrollerHeight);
    const desiredScrollerCentre = clientY - this.#dragOffset;

    return Math.min(
      1,
      Math.max(
        0,
        (desiredScrollerCentre - rect.top - scrollerHeight / 2) / travel
      )
    );
  }

  #isInteractiveTarget(target) {
    return target?.closest?.(
      "a, button, input, select, textarea, summary, [contenteditable='true'], [data-timeline-scrubber-ignore]"
    );
  }

  #latchAndCommit(progress) {
    const finalProgress = Math.min(1, Math.max(0, progress));
    this.latchedProgress = finalProgress;

    if (this.#latchTimeout) {
      clearTimeout(this.#latchTimeout);
    }
    this.#latchTimeout = setTimeout(() => {
      this.latchedProgress = null;
      this.#latchTimeout = null;
    }, LATCH_TIMEOUT_MS);

    this.args.onCommit?.(finalProgress);
  }

  @action
  onPointerDown(event) {
    if (event.button !== 0 || this.#isInteractiveTarget(event.target)) {
      return;
    }

    event.preventDefault();
    // Starting a new drag invalidates any prior latch (the user is
    // overriding the previous commit before its @progress arrived).
    this.#clearLatch();
    this.dragging = true;
    event.currentTarget.setPointerCapture?.(event.pointerId);
    const scroller = event.target.closest?.(".timeline-scroller");
    if (scroller) {
      const rect = scroller.getBoundingClientRect();
      this.#dragOffset = event.clientY - (rect.top + rect.height / 2);
    } else {
      this.#dragOffset = 0;
    }
    this.dragProgress = this.#progressFromClientY(event.clientY);
    this.args.onDragStart?.();
    this.args.onDrag?.(this.dragProgress);
  }

  @action
  onPointerMove(event) {
    if (!this.dragging) {
      return;
    }
    this.dragProgress = this.#progressFromClientY(event.clientY);
    this.args.onDrag?.(this.dragProgress);
  }

  @action
  onPointerUp(event) {
    if (!this.dragging) {
      return;
    }
    event.currentTarget.releasePointerCapture?.(event.pointerId);
    const finalProgress = this.dragProgress;
    this.#dragOffset = 0;
    this.#latchAndCommit(finalProgress);
    this.dragging = false;
    this.args.onDragEnd?.();
  }

  @action
  onKeyDown(event) {
    let nextProgress = null;

    switch (event.key) {
      case "ArrowUp":
      case "ArrowLeft":
        nextProgress = this.progress - this.keyboardStep;
        break;
      case "ArrowDown":
      case "ArrowRight":
        nextProgress = this.progress + this.keyboardStep;
        break;
      case "PageUp":
        nextProgress = this.progress - this.keyboardStep * 5;
        break;
      case "PageDown":
        nextProgress = this.progress + this.keyboardStep * 5;
        break;
      case "Home":
        nextProgress = 0;
        break;
      case "End":
        nextProgress = 1;
        break;
    }

    if (nextProgress == null) {
      return;
    }

    event.preventDefault();
    this.#clearLatch();
    this.#latchAndCommit(nextProgress);
  }

  <template>
    {{! template-lint-disable no-pointer-down-event-binding }}
    <div
      role="slider"
      tabindex="0"
      aria-orientation="vertical"
      aria-valuemin="0"
      aria-valuemax="1"
      aria-valuenow={{this.progress}}
      aria-valuetext={{@ariaValueText}}
      aria-label={{@ariaLabel}}
      ...attributes
      class="timeline-scrubber timeline-scrollarea
        {{if this.dragging 'timeline-scrubber--dragging'}}
        {{if @interactiveTrack 'timeline-scrubber--interactive-track'}}"
      style={{this.railStyle}}
      {{this.registerRail}}
      {{this.watchProgress @progress}}
      {{on "pointerdown" this.onPointerDown}}
      {{on "pointermove" this.onPointerMove}}
      {{on "pointerup" this.onPointerUp}}
      {{on "pointercancel" this.onPointerUp}}
      {{on "keydown" this.onKeyDown}}
    >
      <div class="timeline-scrubber__track">
        {{yield this.progress this.dragging to="track"}}
      </div>

      <div
        class="timeline-scrubber__scroller timeline-scroller"
        {{this.registerScroller}}
      >
        <div class="timeline-scrubber__grip timeline-handle"></div>
        <div
          class="timeline-scrubber__scroller-content timeline-scroller-content"
        >
          {{yield this.progress this.dragging to="handle"}}
        </div>
      </div>
    </div>
  </template>
}
