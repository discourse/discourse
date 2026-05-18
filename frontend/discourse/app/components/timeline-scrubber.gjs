import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import { modifier } from "ember-modifier";

export const SCROLLER_HEIGHT = 50;

export default class TimelineScrubber extends Component {
  @tracked dragging = false;
  @tracked dragProgress = 0;

  registerRail = modifier((el) => {
    this.#railEl = el;
    return () => (this.#railEl = null);
  });

  registerScroller = modifier((el) => {
    this.#scrollerEl = el;
    return () => (this.#scrollerEl = null);
  });

  #railEl = null;
  #scrollerEl = null;
  #dragOffset = 0;

  get progress() {
    return this.dragging ? this.dragProgress : (this.args.progress ?? 0);
  }

  get railStyle() {
    let css = `--scrubber-progress: ${this.progress.toFixed(4)}`;
    if (this.args.height != null) {
      css += `; height: ${this.args.height}px`;
    }
    return trustHTML(css);
  }

  get keyboardStep() {
    return this.args.keyboardStep ?? 0.05;
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

  #commit(progress) {
    this.args.onCommit?.(Math.min(1, Math.max(0, progress)));
  }

  @action
  onPointerDown(event) {
    if (event.button !== 0 || this.#isInteractiveTarget(event.target)) {
      return;
    }

    event.preventDefault();
    this.dragging = true;
    event.currentTarget.setPointerCapture?.(event.pointerId);
    if (this.#scrollerEl?.contains(event.target)) {
      const rect = this.#scrollerEl.getBoundingClientRect();
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
    this.dragging = false;
    this.#commit(finalProgress);
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
    this.#commit(nextProgress);
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
        {{if this.dragging 'timeline-scrubber--dragging'}}"
      style={{this.railStyle}}
      {{this.registerRail}}
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
