import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { throttle } from "@ember/runloop";
import { trustHTML } from "@ember/template";
import { modifier } from "ember-modifier";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { bind } from "discourse/lib/decorators";
import { isTesting } from "discourse/lib/environment";
import { isDocumentRTL } from "discourse/lib/text-direction";
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

export default class ImageCarousel extends Component {
  @tracked currentIndex = 0;
  @tracked isScrolling = false;

  slides = new Map();
  wrapSlots = new Map();
  suppressDragWrap = false;
  /** @type {?{ element: HTMLElement, destSlide: HTMLElement }} */
  wrapMove = null;
  animationFrame = null;
  pendingKeyDirection = null;
  carouselElement;
  trackElement;
  wrapSlotObserver;
  animationTarget;
  scrollStopTimer;

  registerSlide = modifier((element, [index]) => {
    this.slides.set(index, element);
    return () => this.slides.delete(index);
  });

  setupCarousel = modifier((element) => {
    this.carouselElement = element;
  });

  registerWrapSlot = modifier((element, [which]) => {
    this.wrapSlots.set(which, element);
    this.wrapSlotObserver?.observe(element);
    return () => {
      this.wrapSlotObserver?.unobserve(element);
      this.wrapSlots.delete(which);
    };
  });

  setupTrack = modifier((element) => {
    this.trackElement = element;

    // rAF defers until child slide modifiers register, then centers slide 0
    // past the leading wrap slot.
    const initialScroll = requestAnimationFrame(() => {
      if (element.isConnected) {
        this.slides.get(0)?.scrollIntoView({
          behavior: "instant",
          block: "nearest",
          inline: "center",
        });
      }
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

    const controller = new AbortController();
    const { signal } = controller;
    element.addEventListener("scroll", this.onScroll, {
      passive: true,
      signal,
    });
    element.addEventListener("touchstart", this.focusCarousel, {
      passive: true,
      signal,
    });
    element.addEventListener("wheel", this.focusCarousel, {
      passive: true,
      signal,
    });

    if (USE_SCROLLEND) {
      element.addEventListener("scrollend", this.onScrollSettled, { signal });
    }

    // Sync to fullscreen lightbox slide changes (photoswipe).
    element.addEventListener(
      "discourse-lightbox-change",
      this.onLightboxSlideChange,
      { signal }
    );

    return () => {
      controller.abort();
      this.wrapSlotObserver?.disconnect();
      clearTimeout(this.scrollStopTimer);
      cancelAnimationFrame(initialScroll);
      this.cancelAnimation();
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
    if (!this.wrapMove) {
      return false;
    }

    this.wrapMove.destSlide.appendChild(this.wrapMove.element);
    this.wrapMove = null;
    return true;
  }

  // Finish a wrap: return the moved element to its destination slide and
  // teleport scrollLeft from the wrap slot to that slide's centered position.
  finishWrap() {
    const dest = this.wrapMove?.destSlide;
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
      // finishWrap teleports to the destination if a wrap is set up.
      if (!this.finishWrap()) {
        track.scrollTo({ left: target, behavior: "instant" });
      }
      return;
    }

    // Suspend snap + smooth-scroll for the rAF's lifetime: smooth would
    // re-animate each assignment (tripping the divergence abort); snap would
    // yank intermediate positions to snap points.
    track.style.scrollSnapType = "none";
    track.style.scrollBehavior = "auto";

    this.isScrolling = true;
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

      // External interaction (drag/swipe/wheel) perturbed position: abort
      // and leave any wrap-moved element parked for the gesture handlers.
      if (Math.abs(current - lastSet) > 2) {
        this.cancelAnimation();
        return;
      }

      const distance = this.animationTarget - current;
      // Snap to target near the end — exponential approach crawls in
      // sub-pixel land and reads as an fps stutter.
      if (Math.abs(distance) < 2) {
        // For a wrap, finishWrap teleports directly to the destination so
        // the snap engine never sees the slot's center as committed.
        if (!this.finishWrap()) {
          t.scrollLeft = this.animationTarget;
        }

        // Defer style restore one frame: snap still has the pre-teleport
        // target committed and would smooth-scroll back toward it.
        cancelAnimationFrame(this.animationFrame);
        this.animationFrame = null;
        requestAnimationFrame(() => this.restoreScrollStyles());
        return;
      }

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
  }

  // Restore the native snap + smooth-scroll CSS overrides set during a
  // programmatic teleport or rAF animation.
  restoreScrollStyles() {
    if (this.trackElement) {
      this.trackElement.style.scrollSnapType = "";
      this.trackElement.style.scrollBehavior = "";
    }
  }

  // Snap any in-flight wrap home so the next nav starts from a clean position.
  // Otherwise the old rAF's divergence check would trip its abort branch.
  settleInFlightWrap() {
    if (this.wrapMove && this.animationFrame !== null) {
      this.finishWrap();
      cancelAnimationFrame(this.animationFrame);
      this.animationFrame = null;
    } else {
      this.returnMovedElement();
    }
  }

  // Returns the slide or wrap slot to scroll to. When `wrap` is true and the
  // move crosses a boundary, parks the destination item in the adjacent slot
  // as a side effect (mutates wrapMove); finishWrap moves it back and
  // teleports afterwards.
  prepareScrollTarget(index, wrap) {
    if (wrap) {
      const wrapNext = this.currentIndex === this.lastIndex && index === 0;
      const wrapPrev = this.currentIndex === 0 && index === this.lastIndex;

      if (wrapNext || wrapPrev) {
        const slot = this.wrapSlots.get(wrapNext ? "trailing" : "leading");
        const destSlide = this.slides.get(index);
        const item = wrapNext ? this.firstItem : this.lastItem;

        if (slot && destSlide && item?.element) {
          slot.appendChild(item.element);
          this.wrapMove = { element: item.element, destSlide };
          return slot;
        }
      }
    }

    return this.slides.get(index);
  }

  @action
  next() {
    this.scrollToIndex(this.nextIndex, { wrap: true });
  }

  @action
  prev() {
    this.scrollToIndex(this.prevIndex, { wrap: true });
  }

  navigateByKey(direction) {
    const goNext = (direction === "right") !== isDocumentRTL();
    if (goNext) {
      this.next();
    } else {
      this.prev();
    }
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
    // rAF finish handles its own teleport; perturbing scrollLeft would trip
    // its external-scroll abort.
    if (this.animationFrame !== null || this.suppressDragWrap) {
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

      // IO entries can be stale by callback time (e.g. rAF-finish briefly
      // touched the slot then teleported away). Verify current position.
      if (
        Math.abs(
          this.computeTargetScrollLeft(entry.target) - track.scrollLeft
        ) > 1
      ) {
        continue;
      }

      if (this.wrapMove?.element.parentElement === entry.target) {
        this.returnMovedElement();
      }

      this.currentIndex = destIndex;
      this.teleportToSlide(destSlide);
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
    } else {
      this.returnMovedElement();
    }
  }

  ensureMovedTo(slotName, item, destSlide) {
    if (this.wrapMove?.element === item?.element) {
      return;
    }

    this.returnMovedElement();
    const slot = this.wrapSlots.get(slotName);
    if (slot && destSlide && item?.element) {
      slot.appendChild(item.element);
      this.wrapMove = { element: item.element, destSlide };
    }
  }

  @bind
  updateIndex() {
    // During our own rAF, scrollLeft is mid-transit; the nearest-slide read
    // would clobber the synchronously-set currentIndex.
    if (this.animationFrame !== null) {
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

    if (this.wrapMove || this.suppressDragWrap) {
      return;
    }

    // At a boundary, pre-move the wrap item into its slot on input (one frame
    // earlier than the first scroll event) to avoid an empty-slot flash.
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
    // scrollend can fire mid-rAF; let its finish branch handle the wrap.
    if (this.animationFrame !== null) {
      return;
    }

    this.isScrolling = false;
    this.suppressDragWrap = false;
    // Only teleport if we actually rest in a wrap slot — otherwise a momentum
    // overshoot that snapped back to a real slide would yank scrollLeft.
    if (this.atWrapSlot()) {
      this.finishWrap();
    } else {
      this.returnMovedElement();
    }

    this.updateIndex();

    if (this.pendingKeyDirection) {
      const direction = this.pendingKeyDirection;
      this.pendingKeyDirection = null;
      this.navigateByKey(direction);
    }
  }

  @bind
  onScroll() {
    this.isScrolling = true;

    // Optimistic update for real-time dot feedback.
    if (!isTesting()) {
      throttle(this, this.updateIndex, SCROLL_THROTTLE_MS);
    }

    // Fallback for browsers without scrollend (Safari < 17.4).
    if (!USE_SCROLLEND) {
      clearTimeout(this.scrollStopTimer);
      this.scrollStopTimer = setTimeout(this.onScrollSettled, 150);
    }

    // During a user drag past the ends, park the wrap item in the adjacent
    // slot. Click-wrap rAFs manage their own moves.
    if (this.animationFrame === null) {
      this.updateDragWrapContent();
    }
  }

  @action
  scrollToIndex(index, { wrap = false } = {}) {
    this.settleInFlightWrap();
    const element = this.prepareScrollTarget(index, wrap);
    const track = this.trackElement;
    if (!element || !track) {
      return;
    }

    this.currentIndex = index;
    const target = this.computeTargetScrollLeft(element);
    if (Math.abs(track.scrollLeft - target) < 1) {
      return;
    }

    this.animateScrollTo(target);
  }

  // Suspend snap + smooth, scroll instantly to a slide's centered position,
  // then schedule restoration. Without the suspend the snap engine would
  // smooth-scroll back to its pre-teleport target.
  teleportToSlide(slide) {
    const track = this.trackElement;
    if (!track) {
      return;
    }

    track.style.scrollSnapType = "none";
    track.style.scrollBehavior = "auto";
    track.scrollTo({
      left: this.computeTargetScrollLeft(slide),
      behavior: "instant",
    });
    this.suppressDragWrap = true;
    requestAnimationFrame(() => this.restoreScrollStyles());
  }

  // Instant (no-animation) navigation. Used to sync the carousel underneath
  // the fullscreen lightbox when the user swipes through it.
  instantNavigateTo(index) {
    const slide = this.slides.get(index);
    if (!slide || index === this.currentIndex) {
      return;
    }

    this.cancelAnimation();
    this.returnMovedElement();
    this.currentIndex = index;
    this.teleportToSlide(slide);
  }

  @bind
  onLightboxSlideChange(event) {
    const idx = this.items.findIndex((item) =>
      item.element.contains(event.target)
    );
    if (idx !== -1) {
      this.instantNavigateTo(idx);
    }
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
        <div
          {{this.setupTrack}}
          class={{concatClass
            "d-image-carousel__track"
            (if this.isScrolling "is-scrolling")
          }}
        >
          <div
            {{this.registerWrapSlot "leading"}}
            inert
            class="d-image-carousel__slide d-image-carousel__slide--wrap-slot"
          ></div>

          {{#each this.items as |item index|}}
            <div
              {{this.registerSlide index}}
              data-index={{index}}
              style={{trustHTML
                (concat "aspect-ratio: " item.width " / " item.height)
              }}
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
            @action={{this.prev}}
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
            @action={{this.next}}
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
