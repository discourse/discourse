import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
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
// Approximate scroll animation duration (~99% of the distance covered).
const ANIMATION_DURATION_MS = 1250;
const ANIMATION_FINISH_THRESHOLD = 0.5;
const EXTERNAL_SCROLL_TOLERANCE_PX = 2;

function plusOne(val) {
  return val + 1;
}

function getAspectRatio(width, height) {
  const w = parseInt(width, 10) || 1;
  const h = parseInt(height, 10) || 1;
  return trustHTML(`aspect-ratio: ${w} / ${h}`);
}

export default class ImageCarousel extends Component {
  @tracked currentIndex = 0;

  registerSlide = modifier((element, [index]) => {
    this.slides.set(index, element);
    return () => this.slides.delete(index);
  });

  registerClone = modifier((element, [which]) => {
    this.clones.set(which, element);
    this.cloneObserver?.observe(element);
    return () => {
      this.cloneObserver?.unobserve(element);
      this.clones.delete(which);
    };
  });

  setupCarousel = modifier((element) => {
    this.carouselElement = element;
    return () => {
      this.carouselElement = null;
    };
  });

  setupTrack = modifier((element) => {
    this.trackElement = element;
    this.trackDirection =
      getComputedStyle(element).direction === "rtl" ? -1 : 1;

    // rAF defers until child slide modifiers register, then centers slide 0
    // past the leading clone.
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

    // threshold: 1 fires only when a clone is fully visible — exactly when
    // the snap-to-clone animation completes. A lower threshold would fire
    // mid-animation and perturb the in-flight snap.
    this.cloneObserver = new IntersectionObserver(this.onCloneIntersect, {
      root: element,
      threshold: 1,
    });
    this.clones.forEach((clone) => this.cloneObserver.observe(clone));

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

      this.cloneObserver?.disconnect();
      this.cloneObserver = null;
      clearTimeout(this.scrollStopTimer);
      cancelAnimationFrame(initialScroll);
      this.cancelAnimation();
      this.trackElement = null;
    };
  });

  trackDirection = 1;
  trackElement = null;
  carouselElement = null;
  programmaticScroll = false;
  slides = new Map();
  clones = new Map();
  animationFrame = null;
  animationTarget = null;
  scrollStopTimer = null;
  cloneObserver = null;
  isScrolling = false;
  pendingKeyDirection = null;

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

  @cached
  get firstCloneNode() {
    return this.firstItem?.element?.cloneNode(true);
  }

  @cached
  get lastCloneNode() {
    return this.lastItem?.element?.cloneNode(true);
  }

  // Real-slide index nearest the viewport center. Clones report the index
  // of the slide they duplicate.
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
    this.clones.forEach((el, which) =>
      consider(el, which === "first" ? 0 : this.lastIndex)
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

  // If scrolled into a clone wrap zone, jump by (N * slideWidth) to the
  // equivalent real-strip position. Invisible since clones mirror their real
  // counterparts; lets follow-up animations take the short path.
  teleportFromWrapZone() {
    const track = this.trackElement;
    const slideWidth = track?.clientWidth;
    if (!slideWidth) {
      return false;
    }

    const wrapDistance = this.items.length * slideWidth;
    const sl = track.scrollLeft;
    let teleportTarget;

    if (sl > wrapDistance) {
      teleportTarget = sl - wrapDistance;
    } else if (sl < slideWidth) {
      teleportTarget = sl + wrapDistance;
    } else {
      return false;
    }

    // "instant" bypasses CSS scroll-behavior: smooth — otherwise this would
    // visibly animate across the entire strip.
    track.scrollTo({ left: teleportTarget, behavior: "instant" });
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
      this.teleportFromWrapZone();
      // "instant" overrides CSS scroll-behavior: smooth.
      track.scrollTo({ left: target, behavior: "instant" });
      return;
    }

    // Suspend snap + CSS smooth-scroll for the rAF's lifetime: smooth would
    // re-animate each scrollLeft assignment (tripping the divergence abort);
    // snap would yank intermediate positions to snap points. Idempotent.
    track.style.scrollSnapType = "none";
    track.style.scrollBehavior = "auto";

    // Rapid re-click while a previous wrap is mid-flight: teleport to the
    // real-strip equivalent and cancel the rAF — its lastSet would otherwise
    // diverge from the post-teleport scrollLeft and trigger the abort below.
    if (this.teleportFromWrapZone() && this.animationFrame !== null) {
      cancelAnimationFrame(this.animationFrame);
      this.animationFrame = null;
    }

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
      if (Math.abs(current - lastSet) > EXTERNAL_SCROLL_TOLERANCE_PX) {
        this.cancelAnimation();
        return;
      }

      const distance = this.animationTarget - current;
      if (Math.abs(distance) < ANIMATION_FINISH_THRESHOLD) {
        t.scrollLeft = this.animationTarget;
        // If we landed on a clone, silently teleport to its real counterpart.
        // currentIndex was already set to the wrap target by scrollToIndex.
        this.teleportFromWrapZone();
        this.cancelAnimation();
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

    // restore native snap + smooth-scroll
    const track = this.trackElement;
    if (track) {
      track.style.scrollSnapType = "";
      track.style.scrollBehavior = "";
    }
    this.programmaticScroll = false;
  }

  // For wrap-crossing nav, return the adjacent clone so the scroll animates
  // one slide-width. The rAF finish branch teleports to the real counterpart.
  scrollTargetFor(index, direction) {
    if (
      direction === "next" &&
      this.currentIndex === this.lastIndex &&
      index === 0
    ) {
      return this.clones.get("first");
    }

    if (
      direction === "prev" &&
      this.currentIndex === 0 &&
      index === this.lastIndex
    ) {
      return this.clones.get("last");
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

  @bind
  onCloneIntersect(entries) {
    // Don't fight an in-flight rAF wrap; perturbing scrollLeft would trip
    // its external-scroll abort. The rAF's own finish branch handles the
    // teleport.
    if (this.animationFrame !== null) {
      return;
    }

    for (const entry of entries) {
      if (!entry.isIntersecting) {
        continue;
      }
      const realIndex =
        entry.target === this.clones.get("first") ? 0 : this.lastIndex;
      const realSlide = this.slides.get(realIndex);
      if (realSlide) {
        this.trackElement?.scrollTo({
          left: this.computeTargetScrollLeft(realSlide),
          behavior: "instant",
        });
      }
      return;
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
  }

  @bind
  onScrollSettled() {
    // Browser can fire scrollend mid-rAF; teleporting here would trip its
    // external-scroll abort. The rAF's own finish branch handles the wrap.
    if (this.animationFrame !== null) {
      return;
    }

    this.isScrolling = false;
    this.programmaticScroll = false;
    this.teleportFromWrapZone();
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
            {{this.registerClone "last"}}
            inert
            style={{getAspectRatio this.lastItem.width this.lastItem.height}}
            class="d-image-carousel__slide d-image-carousel__slide--clone"
          >
            {{this.lastCloneNode}}
          </div>

          {{#each this.items as |item index|}}
            <div
              {{this.registerSlide index}}
              data-index={{index}}
              style={{getAspectRatio item.width item.height}}
              class={{concatClass
                "d-image-carousel__slide"
                (if (eq this.currentIndex index) "is-active")
              }}
            >
              {{item.element}}
            </div>
          {{/each}}

          <div
            {{this.registerClone "first"}}
            inert
            style={{getAspectRatio this.firstItem.width this.firstItem.height}}
            class="d-image-carousel__slide d-image-carousel__slide--clone"
          >
            {{this.firstCloneNode}}
          </div>
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
