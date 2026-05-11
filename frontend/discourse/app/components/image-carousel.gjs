import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { throttle } from "@ember/runloop";
import { trustHTML } from "@ember/template";
import { modifier } from "ember-modifier";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { bind } from "discourse/lib/decorators";
import { isTesting } from "discourse/lib/environment";
import { prefersReducedMotion } from "discourse/lib/utilities";
import { eq, lte } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

const KEYBOARD_THROTTLE_MS = isTesting() ? 0 : 150;
const SCROLL_THROTTLE_MS = 50;
const MAX_DOTS = 8;
const USE_SCROLLEND = !isTesting() && "onscrollend" in window;
const ANIMATION_DURATION_MS = 800;

function plusOne(val) {
  return val + 1;
}

function aspectRatioStyle(width, height) {
  const w = parseInt(width, 10) || 1;
  const h = parseInt(height, 10) || 1;
  return trustHTML(`aspect-ratio: ${w} / ${h}`);
}

export default class ImageCarousel extends Component {
  @tracked currentIndex = 0;

  trackDirection = 1;
  trackElement = null;
  carouselElement = null;
  programmaticScroll = false;
  slides = new Map();
  wrapSlots = new Map();
  wrapSlotObserver = null;
  movedElement = null;
  movedToSlide = null;
  animationFrame = null;
  animationTarget = null;
  scrollStopTimer = null;
  isScrolling = false;
  pendingKeyDirection = null;
  suppressDragWrap = false;

  registerSlide = modifier((element, [index]) => {
    this.slides.set(index, element);
    return () => this.slides.delete(index);
  });

  registerWrapSlot = modifier((element, [which]) => {
    this.wrapSlots.set(which, element);
    this.wrapSlotObserver?.observe(element);
    return () => {
      this.wrapSlotObserver?.unobserve(element);
      this.wrapSlots.delete(which);
    };
  });

  setupCarousel = modifier((element) => {
    this.carouselElement = element;
    return () => (this.carouselElement = null);
  });

  setupTrack = modifier((element) => {
    this.trackElement = element;
    this.trackDirection =
      getComputedStyle(element).direction === "rtl" ? -1 : 1;

    // rAF defers until child slide modifiers register, then centers slide 0
    // past the leading wrap slot.
    const initialScroll = requestAnimationFrame(() => {
      if (!element.isConnected) {
        return;
      }

      this.slides.get(0)?.scrollIntoView({
        behavior: "instant",
        block: "nearest",
        inline: "center",
      });
    });

    // threshold: 1 fires exactly when a wrap slot is fully visible — the
    // instant a drag-scroll reaches it. Teleporting here (rather than
    // waiting for scrollend) lets continuous trackpad momentum carry through
    // the wrap without a forced stop.
    this.wrapSlotObserver = new IntersectionObserver(this.onWrapSlotIntersect, {
      root: element,
      threshold: 1,
    });
    this.wrapSlots.forEach((slot) => this.wrapSlotObserver.observe(slot));

    element.addEventListener("scroll", this.onScroll, { passive: true });
    element.addEventListener("touchstart", this.focusCarousel, {
      passive: true,
    });
    element.addEventListener("wheel", this.focusCarousel, { passive: true });
    if (USE_SCROLLEND) {
      element.addEventListener("scrollend", this.onScrollSettled);
    }

    return () => {
      element.removeEventListener("scroll", this.onScroll);
      element.removeEventListener("touchstart", this.focusCarousel);
      element.removeEventListener("wheel", this.focusCarousel);
      if (USE_SCROLLEND) {
        element.removeEventListener("scrollend", this.onScrollSettled);
      }

      this.wrapSlotObserver?.disconnect();
      this.wrapSlotObserver = null;
      clearTimeout(this.scrollStopTimer);
      cancelAnimationFrame(initialScroll);
      this.cancelAnimation();
      this.returnMovedElement();
      this.trackElement = null;
    };
  });

  get items() {
    return this.args.data.items || [];
  }

  get prevIndex() {
    return this.currentIndex === 0 ? this.lastIndex : this.currentIndex - 1;
  }

  get nextIndex() {
    return this.currentIndex === this.lastIndex ? 0 : this.currentIndex + 1;
  }

  get lastIndex() {
    return this.items.length - 1;
  }

  get firstItem() {
    return this.items[0];
  }

  get lastItem() {
    return this.items[this.lastIndex];
  }

  // Real-slide index nearest the viewport center. Wrap slots map to the
  // index of the slide they're standing in for (trailing → 0, leading →
  // lastIndex), so dragging into a wrap slot reads as "at the destination".
  nearestRealIndex() {
    const track = this.trackElement;
    if (!track) {
      return this.currentIndex;
    }

    const trackCenter = track.scrollLeft + track.clientWidth / 2;
    let best = this.currentIndex;
    let minDistance = Infinity;

    const consider = (element, index) => {
      const distance = Math.abs(
        element.offsetLeft + element.offsetWidth / 2 - trackCenter
      );
      if (distance < minDistance) {
        minDistance = distance;
        best = index;
      }
    };

    this.slides.forEach(consider);
    this.wrapSlots.forEach((element, which) =>
      consider(element, which === "trailing" ? 0 : this.lastIndex)
    );

    return best;
  }

  computeTargetScrollLeft(slideElement) {
    return (
      slideElement.offsetLeft +
      slideElement.offsetWidth / 2 -
      this.trackElement.clientWidth / 2
    );
  }

  // Put the moved element back into its destination slide. No scroll change.
  returnMovedElement() {
    if (!this.movedElement || !this.movedToSlide) {
      return false;
    }
    this.movedToSlide.appendChild(this.movedElement);
    this.movedElement = null;
    this.movedToSlide = null;
    return true;
  }

  // Finish a wrap: return the moved element to its destination slide and
  // teleport scrollLeft from the wrap slot to that slide's centered position.
  finishWrap() {
    const dest = this.movedToSlide;
    if (!dest || !this.returnMovedElement() || !this.trackElement) {
      return false;
    }
    // "instant" bypasses CSS scroll-behavior: smooth.
    this.trackElement.scrollTo({
      left: this.computeTargetScrollLeft(dest),
      behavior: "instant",
    });
    return true;
  }

  // rAF-driven scroll. Rapid retargets update animationTarget.
  animateScrollTo(target) {
    const track = this.trackElement;
    if (!track) {
      return;
    }

    if (prefersReducedMotion()) {
      this.cancelAnimation();
      // If a wrap was just set up, finishWrap teleports to the destination
      // slide and overrides the slot target. Otherwise teleport directly.
      if (!this.finishWrap()) {
        // "instant" overrides CSS scroll-behavior: smooth.
        track.scrollTo({ left: target, behavior: "instant" });
      }
      return;
    }

    // Suspend snap + CSS smooth-scroll for the rAF's lifetime: smooth would
    // re-animate each scrollLeft assignment (tripping the divergence abort);
    // snap would yank intermediate positions to snap points. Idempotent.
    track.style.scrollSnapType = "none";
    track.style.scrollBehavior = "auto";

    this.animationTarget = target;
    if (this.animationFrame !== null) {
      return;
    }

    let lastSet = track.scrollLeft;
    let lastFrameTime = null;

    const tick = (now) => {
      const t = this.trackElement;
      if (!t) {
        this.animationFrame = null;
        return;
      }

      const current = t.scrollLeft;

      // Abort if external interaction (drag/swipe/wheel) perturbed position.
      // Leave any wrap-moved element parked; updateDragWrapContent /
      // onScrollSettled clean up based on where the user ends up.
      if (Math.abs(current - lastSet) > 2) {
        this.cancelAnimation();
        return;
      }

      const distance = this.animationTarget - current;
      // Within a couple of pixels: snap to target. Exponential approach
      // crawls in sub-pixel land otherwise and reads as an fps stutter.
      if (Math.abs(distance) < 2) {
        // For a wrap, finishWrap teleports directly to the destination slide
        // — skip the intermediate scrollLeft = animationTarget assignment so
        // the browser's snap engine never observes the wrap slot's center as
        // a committed scroll target. For non-wraps it returns false and we
        // snap to animationTarget here.
        if (!this.finishWrap()) {
          t.scrollLeft = this.animationTarget;
        }
        // Inline cleanup (not cancelAnimation): defer the snap/smooth-scroll
        // restore to the next frame. Otherwise the snap engine, which still
        // has its pre-teleport target committed, smooth-scrolls scrollLeft
        // back toward it and (with scroll-snap-stop: always) lands at the
        // first snap point along the way.
        cancelAnimationFrame(this.animationFrame);
        this.animationFrame = null;
        this.programmaticScroll = false;
        requestAnimationFrame(() => this.restoreScrollStyles());
        return;
      }

      // Frame-rate-independent exponential approach.
      const dt = lastFrameTime === null ? 1000 / 60 : now - lastFrameTime;
      lastFrameTime = now;
      const rate = 1 - 0.01 ** (dt / ANIMATION_DURATION_MS);
      const next = current + distance * rate;
      t.scrollLeft = next;
      lastSet = next;
      this.animationFrame = requestAnimationFrame(tick);
    };

    this.animationFrame = requestAnimationFrame(tick);
  }

  cancelAnimation() {
    if (this.animationFrame !== null) {
      cancelAnimationFrame(this.animationFrame);
      this.animationFrame = null;
    }
    this.restoreScrollStyles();
    this.programmaticScroll = false;
  }

  // Restore the native snap + smooth-scroll CSS overrides set during a
  // programmatic teleport or rAF animation.
  restoreScrollStyles() {
    if (this.trackElement) {
      this.trackElement.style.scrollSnapType = "";
      this.trackElement.style.scrollBehavior = "";
    }
  }

  // For wrap-crossing nav, move the destination item's element into the
  // adjacent (initially empty) wrap slot so the scroll animates a single
  // slide-width to it. finishWrap moves it back and teleports afterwards.
  scrollTargetFor(index, direction) {
    // Clean up any prior wrap state before deciding a new target. If a wrap
    // is mid-flight (rAF running), teleport to its destination so the next
    // animation starts from a clean position, and cancel the rAF so the new
    // animateScrollTo starts fresh (otherwise the old rAF's lastSet would
    // diverge and trigger its abort instead of redirecting smoothly).
    if (this.movedElement && this.animationFrame !== null) {
      this.finishWrap();
      cancelAnimationFrame(this.animationFrame);
      this.animationFrame = null;
    } else {
      this.returnMovedElement();
    }

    const wrapNext =
      direction === "next" &&
      this.currentIndex === this.lastIndex &&
      index === 0;
    const wrapPrev =
      direction === "prev" &&
      this.currentIndex === 0 &&
      index === this.lastIndex;

    if (wrapNext || wrapPrev) {
      const slot = this.wrapSlots.get(wrapNext ? "trailing" : "leading");
      const destSlide = this.slides.get(index);
      const item = wrapNext ? this.firstItem : this.lastItem;
      if (slot && destSlide && item?.element) {
        slot.appendChild(item.element);
        this.movedElement = item.element;
        this.movedToSlide = destSlide;
        return slot;
      }
    }

    return this.slides.get(index);
  }

  navigateByKey(direction) {
    const ltr = this.trackDirection === 1;
    const goNext = (direction === "right") === ltr;
    this.scrollToIndex(
      goNext ? this.nextIndex : this.prevIndex,
      goNext ? "next" : "prev"
    );
  }

  // True iff scrollLeft has come to rest at a wrap slot's centered position.
  atWrapSlot() {
    const track = this.trackElement;
    if (!track) {
      return false;
    }
    for (const slot of this.wrapSlots.values()) {
      if (Math.abs(this.computeTargetScrollLeft(slot) - track.scrollLeft) < 1) {
        return true;
      }
    }
    return false;
  }

  @bind
  onWrapSlotIntersect(entries) {
    // Don't fight an in-flight click-wrap rAF; its own finish branch handles
    // the teleport. Perturbing scrollLeft would trip the rAF's external-
    // scroll abort.
    if (this.animationFrame !== null) {
      return;
    }
    if (this.suppressDragWrap) {
      return;
    }

    for (const entry of entries) {
      if (!entry.isIntersecting) {
        continue;
      }
      const isTrailing = entry.target === this.wrapSlots.get("trailing");
      const destIndex = isTrailing ? 0 : this.lastIndex;
      const destSlide = this.slides.get(destIndex);
      const track = this.trackElement;
      if (!destSlide || !track) {
        return;
      }
      // IO entries reflect the intersection state at the time it was recorded,
      // not at callback time. If a rAF-finish briefly set scrollLeft to the
      // slot's center before teleporting away, the entry says "intersecting"
      // even though we're no longer there. Verify against current scrollLeft
      // before acting on it.
      if (
        Math.abs(
          this.computeTargetScrollLeft(entry.target) - track.scrollLeft
        ) > 1
      ) {
        continue;
      }
      // If a drag-wrap parked the element here, hand it back to its slide.
      if (
        this.movedElement &&
        this.movedElement.parentElement === entry.target
      ) {
        this.returnMovedElement();
      }
      // Disable snap + smooth around the teleport. Without this, the snap
      // engine remembers its pre-teleport target (the wrap slot) and
      // smooth-scrolls back to it after we jump away.
      track.style.scrollSnapType = "none";
      track.style.scrollBehavior = "auto";
      track.scrollTo({
        left: this.computeTargetScrollLeft(destSlide),
        behavior: "instant",
      });
      this.currentIndex = destIndex;
      this.suppressDragWrap = true;
      requestAnimationFrame(() => this.restoreScrollStyles());
      return;
    }
  }

  updateDragWrapContent() {
    if (this.suppressDragWrap) {
      return;
    }
    const track = this.trackElement;
    const firstSlide = this.slides.get(0);
    const lastSlide = this.slides.get(this.lastIndex);
    if (!track || !firstSlide || !lastSlide) {
      return;
    }

    // Move the wrap content the instant its slot starts entering the
    // viewport (not once it's already half-visible).
    const sl = track.scrollLeft;
    const pastLast = sl > lastSlide.offsetLeft;
    const beforeFirst = sl < firstSlide.offsetLeft;

    if (pastLast) {
      this.ensureMovedTo("trailing", this.firstItem, firstSlide);
    } else if (beforeFirst) {
      this.ensureMovedTo("leading", this.lastItem, lastSlide);
    } else if (this.movedElement) {
      this.returnMovedElement();
    }
  }

  ensureMovedTo(slotName, item, destSlide) {
    if (this.movedElement === item?.element) {
      return;
    }
    this.returnMovedElement();
    const slot = this.wrapSlots.get(slotName);
    if (slot && destSlide && item?.element) {
      slot.appendChild(item.element);
      this.movedElement = item.element;
      this.movedToSlide = destSlide;
    }
  }

  @bind
  updateIndex() {
    // During a programmatic scroll the position is still near the previous
    // slide and would clobber the target index.
    if (this.programmaticScroll) {
      return;
    }

    const newIndex = this.nearestRealIndex();
    if (newIndex !== this.currentIndex) {
      this.currentIndex = newIndex;
    }
  }

  // Focus on touch/wheel so arrow keys work without a Tab press.
  // preventScroll keeps the page from jumping if the carousel is partially
  // off-screen.
  @bind
  focusCarousel() {
    if (document.activeElement !== this.carouselElement) {
      this.carouselElement?.focus({ preventScroll: true });
    }
    this.preMoveAtBoundary();
  }

  // At a boundary, pre-move the wrap item into its slot on input (one frame
  // earlier than the first scroll event) to avoid an empty-slot flash.
  preMoveAtBoundary() {
    if (this.movedElement || this.suppressDragWrap) {
      return;
    }
    if (this.currentIndex === 0) {
      this.ensureMovedTo(
        "leading",
        this.lastItem,
        this.slides.get(this.lastIndex)
      );
    } else if (this.currentIndex === this.lastIndex) {
      this.ensureMovedTo("trailing", this.firstItem, this.slides.get(0));
    }
  }

  @bind
  onScrollSettled() {
    // Browser can fire scrollend mid-rAF; finishing the wrap here would
    // trip the rAF's external-scroll abort. The rAF's finish branch handles
    // its own wrap.
    if (this.animationFrame !== null) {
      return;
    }

    this.isScrolling = false;
    this.programmaticScroll = false;
    this.suppressDragWrap = false;
    // Only teleport (finishWrap) if scroll actually came to rest at a wrap
    // slot. If updateDragWrapContent set movedElement on a momentum
    // overshoot but snap pulled us back to a real slide, just return the
    // moved element silently — don't yank scrollLeft to a different slide.
    if (this.atWrapSlot()) {
      this.finishWrap();
    } else {
      this.returnMovedElement();
    }
    this.updateIndex();

    // Run any keyboard nav queued during the browser scroll; direction
    // re-resolves against the settled currentIndex.
    if (this.pendingKeyDirection) {
      const direction = this.pendingKeyDirection;
      this.pendingKeyDirection = null;
      this.navigateByKey(direction);
    }
  }

  @bind
  onScroll() {
    this.isScrolling = true;

    // Optimistic update while scrolling for real-time dot feedback
    if (!isTesting()) {
      throttle(this, this.updateIndex, SCROLL_THROTTLE_MS);
    }

    // Fallback for browsers without scrollend support (Safari < 17.4)
    if (!USE_SCROLLEND) {
      clearTimeout(this.scrollStopTimer);
      this.scrollStopTimer = setTimeout(this.onScrollSettled, 150);
    }

    // While the user is drag-scrolling past the strip's ends, move the
    // wrap-around item's element into the adjacent slot so they see real
    // content instead of an empty slot. Click-wrap animations skip this —
    // they manage moves themselves.
    if (!this.programmaticScroll) {
      this.updateDragWrapContent();
    }
  }

  @action
  scrollToIndex(index, direction = null) {
    const element = this.scrollTargetFor(index, direction);
    const track = this.trackElement;
    if (!element || !track) {
      return;
    }

    this.currentIndex = index;
    const target = this.computeTargetScrollLeft(element);
    if (Math.abs(track.scrollLeft - target) < 1) {
      return;
    }

    this.programmaticScroll = true;
    this.animateScrollTo(target);
  }

  @action
  onKeyDown(event) {
    if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") {
      return;
    }

    event.preventDefault();

    const direction = event.key === "ArrowLeft" ? "left" : "right";

    // Queue the nav for scrollend if a browser-driven scroll is in flight —
    // starting an rAF now would just be aborted. (Our own rAF is handled by
    // animateScrollTo's retarget path.)
    if (this.isScrolling && this.animationFrame === null) {
      this.pendingKeyDirection = direction;
      return;
    }

    throttle(this, this.navigateByKey, direction, KEYBOARD_THROTTLE_MS);
  }

  <template>
    {{#if (eq this.items.length 1)}}
      {{this.firstItem.element}}
    {{else if this.items.length}}
      <div
        {{this.setupCarousel}}
        {{on "keydown" this.onKeyDown}}
        tabindex="0"
        class="d-image-carousel"
      >
        <div {{this.setupTrack}} class="d-image-carousel__track">
          <div
            {{this.registerWrapSlot "leading"}}
            inert
            class="d-image-carousel__slide d-image-carousel__slide--wrap-slot"
          ></div>

          {{#each this.items as |item index|}}
            <div
              {{this.registerSlide index}}
              data-index={{index}}
              style={{aspectRatioStyle item.width item.height}}
              class={{concatClass
                "d-image-carousel__slide"
                (if (eq this.currentIndex index) "is-active")
              }}
            >
              {{item.element}}
            </div>
          {{/each}}

          <div
            {{this.registerWrapSlot "trailing"}}
            inert
            class="d-image-carousel__slide d-image-carousel__slide--wrap-slot"
          ></div>
        </div>

        <div class="d-image-carousel__controls">
          <DButton
            @action={{fn this.scrollToIndex this.prevIndex "prev"}}
            @icon="chevron-left"
            @title="carousel.previous"
            aria-label={{i18n "carousel.previous"}}
            class="btn-flat d-image-carousel__nav d-image-carousel__nav--prev"
          />

          {{#if (lte this.items.length MAX_DOTS)}}
            <div class="d-image-carousel__dots">
              {{#each this.items as |_item index|}}
                <button
                  {{on "click" (fn this.scrollToIndex index)}}
                  type="button"
                  aria-current={{if (eq this.currentIndex index) "true"}}
                  aria-label={{i18n
                    "carousel.go_to_slide"
                    index=(plusOne index)
                  }}
                  class={{concatClass
                    "d-image-carousel__dot"
                    (if (eq this.currentIndex index) "active")
                  }}
                ></button>
              {{/each}}
            </div>
          {{else}}
            <span class="d-image-carousel__counter">
              {{plusOne this.currentIndex}}
              /
              {{this.items.length}}
            </span>
          {{/if}}

          <DButton
            @action={{fn this.scrollToIndex this.nextIndex "next"}}
            @icon="chevron-right"
            @title="carousel.next"
            aria-label={{i18n "carousel.next"}}
            class="btn-flat d-image-carousel__nav d-image-carousel__nav--next"
          />
        </div>
      </div>
    {{/if}}
  </template>
}
