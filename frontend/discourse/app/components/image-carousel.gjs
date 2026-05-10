import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
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
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

const KEYBOARD_THROTTLE_MS = isTesting() ? 0 : 150;
const SCROLL_THROTTLE_MS = 50;
const MAX_DOTS = 8;
// Per-frame fraction of remaining distance to cover. Higher = snappier, lower
// = smoother. 0.07 ≈ ~1.3s to fully converge for any single retarget.
const ANIMATION_APPROACH_RATE = 0.07;
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
    this.#slides.set(index, element);
    return () => this.#slides.delete(index);
  });

  registerClone = modifier((element, [which]) => {
    this.#clones.set(which, element);
    this.#cloneObserver?.observe(element);
    return () => {
      this.#cloneObserver?.unobserve(element);
      this.#clones.delete(which);
    };
  });

  setupTrack = modifier((element) => {
    this.#trackElement = element;
    this.#trackDirection =
      getComputedStyle(element).direction === "rtl" ? -1 : 1;
    this.#useScrollEnd = "onscrollend" in window && !isTesting();

    // Skip past the leading clone so the real first slide is centered. rAF
    // gives child slide modifiers a chance to register before we look one up.
    const initialScroll = requestAnimationFrame(() => {
      if (this.isSingle || !element.isConnected) {
        return;
      }

      this.#slides.get(0)?.scrollIntoView({
        behavior: "instant",
        block: "nearest",
        inline: "center",
      });
    });

    // Fires the moment a clone becomes 100% visible in the viewport — which
    // is the exact moment the snap-to-clone animation finishes (and the
    // moment the clone is centered, since slides are viewport-width). Using
    // a lower threshold would fire mid-animation, while a sliver of the
    // adjacent real slide is still showing on screen, and teleporting then
    // causes that sliver to vanish abruptly and the in-flight snap animation
    // to be perturbed.
    this.#cloneObserver = new IntersectionObserver(
      (entries) => {
        // Don't fight an in-flight rAF wrap; its own finish branch handles
        // the teleport. Perturbing scrollLeft here would trip the rAF's
        // external-scroll abort and cause a snap-back glitch.
        if (this.#animationFrame !== null) {
          return;
        }
        for (const entry of entries) {
          if (!entry.isIntersecting) {
            continue;
          }
          const realIndex =
            entry.target === this.#clones.get("first") ? 0 : this.lastIndex;
          const realSlide = this.#slides.get(realIndex);
          if (realSlide) {
            element.scrollTo({
              left: this.#computeTargetScrollLeft(realSlide),
              behavior: "instant",
            });
          }
          return;
        }
      },
      { root: element, threshold: 1 }
    );
    this.#clones.forEach((clone) => this.#cloneObserver.observe(clone));

    element.addEventListener("scroll", this.onScroll, { passive: true });
    element.addEventListener("touchstart", this.focusTrack, { passive: true });
    element.addEventListener("wheel", this.focusTrack, { passive: true });
    if (this.#useScrollEnd) {
      element.addEventListener("scrollend", this.onScrollSettled);
    }

    return () => {
      element.removeEventListener("scroll", this.onScroll);
      element.removeEventListener("touchstart", this.focusTrack);
      element.removeEventListener("wheel", this.focusTrack);
      if (this.#useScrollEnd) {
        element.removeEventListener("scrollend", this.onScrollSettled);
      }

      this.#cloneObserver?.disconnect();
      this.#cloneObserver = null;
      clearTimeout(this.#scrollStopTimer);
      cancelAnimationFrame(initialScroll);
      this.#cancelAnimation();
      this.#trackElement = null;
    };
  });

  #trackDirection = 1;
  #trackElement = null;
  #programmaticScroll = false;
  #slides = new Map();
  #clones = new Map();
  #animationFrame = null;
  #animationTarget = null;
  #useScrollEnd = false;
  #scrollStopTimer = null;
  #cloneObserver = null;

  @bind
  updateIndex() {
    // While a programmatic scroll is in flight, the current scroll position
    // is still near the previous slide and would clobber the target index.
    if (this.#programmaticScroll) {
      return;
    }

    const newIndex = this.#nearestRealIndex(this.#trackElement);
    if (newIndex !== this.currentIndex) {
      this.currentIndex = newIndex;
    }
  }

  // Focus the track on touchstart / wheel so the user can switch between
  // swipe/trackpad and arrow-key navigation without an extra Tab press.
  // preventScroll keeps the browser from scrolling the page if the carousel
  // happens to be partially off-screen when focus moves.
  @bind
  focusTrack() {
    if (document.activeElement !== this.#trackElement) {
      this.#trackElement?.focus({ preventScroll: true });
    }
  }

  @bind
  onScrollSettled() {
    // Don't fight an in-flight rAF: the browser can fire scrollend
    // mid-animation and our teleport here would trip its external-scroll
    // abort. The rAF's finish branch handles the wrap teleport itself.
    if (this.#animationFrame !== null) {
      return;
    }

    this.#programmaticScroll = false;
    this.#teleportFromWrapZone();
    this.updateIndex();
  }

  @bind
  onScroll() {
    // Optimistic update while scrolling for real-time dot feedback
    if (!isTesting()) {
      throttle(this, this.updateIndex, SCROLL_THROTTLE_MS);
    }

    // Fallback for browsers without scrollend support (Safari < 17.4)
    if (!this.#useScrollEnd) {
      clearTimeout(this.#scrollStopTimer);
      this.#scrollStopTimer = setTimeout(this.onScrollSettled, 150);
    }
  }

  // Returns the real-slide index nearest to the viewport center. Clones map
  // to the real slide they visually represent, so a manual drag onto a clone
  // reads the same as being on the real slide it duplicates.
  #nearestRealIndex(track) {
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

    this.#slides.forEach(consider);
    this.#clones.forEach((el, which) =>
      consider(el, which === "first" ? 0 : this.lastIndex)
    );

    return best;
  }

  get #shouldReduceMotion() {
    return window.matchMedia?.("(prefers-reduced-motion: reduce)")?.matches;
  }

  #computeTargetScrollLeft(slideElement) {
    return (
      slideElement.offsetLeft +
      slideElement.offsetWidth / 2 -
      this.#trackElement.clientWidth / 2
    );
  }

  // If scrollLeft is in a clone wrap zone (past slide N-1, or before slide 0),
  // shift it by ±(N * slideWidth) to the equivalent position on the real
  // strip. Invisible because the clone shows the same content as the real
  // slide on the other side of the strip; used so that follow-up animations
  // take the short path instead of scrolling backwards across the strip.
  #teleportFromWrapZone() {
    const track = this.#trackElement;
    const slideWidth = track?.clientWidth;
    if (this.isSingle || !slideWidth) {
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

    // scrollTo with behavior: "instant" bypasses CSS scroll-behavior: smooth;
    // otherwise this would be a visible animation across the entire strip.
    track.scrollTo({ left: teleportTarget, behavior: "instant" });
    return true;
  }

  // Custom rAF-driven animation. Multiple rapid retargets just update
  // #animationTarget — the running rAF loop redirects smoothly toward the new
  // target instead of restarting (which is what native scrollIntoView smooth
  // would do, causing the per-click stutter).
  #animateScrollTo(target) {
    const track = this.#trackElement;
    if (!track) {
      return;
    }

    if (this.#shouldReduceMotion) {
      this.#cancelAnimation();
      this.#teleportFromWrapZone();
      // behavior: "instant" overrides CSS scroll-behavior: smooth — without
      // it a reduce-motion user would still see a smooth animation.
      track.scrollTo({ left: target, behavior: "instant" });
      return;
    }

    // Suspend mandatory snap and CSS smooth-scroll for the rAF's lifetime.
    // Smooth would re-animate every scrollLeft assignment over ~300ms (and
    // the next tick would abort on the divergence); snap would yank
    // intermediate non-snap-point positions to the nearest snap. Idempotent
    // if already suspended by an in-flight rAF.
    this.#suspendNativeScrollEffects();

    // If we're in a clone wrap zone (e.g., an earlier wrap is still mid-flight
    // when the user clicks again), teleport to the real-strip equivalent. If
    // an rAF was running, cancel it — its lastSet now diverges from the
    // post-teleport scrollLeft and the next tick would otherwise abort.
    if (this.#teleportFromWrapZone() && this.#animationFrame !== null) {
      cancelAnimationFrame(this.#animationFrame);
      this.#animationFrame = null;
    }

    this.#animationTarget = target;
    if (this.#animationFrame !== null) {
      return;
    }

    let lastSet = track.scrollLeft;

    const tick = () => {
      const t = this.#trackElement;
      if (!t) {
        this.#animationFrame = null;
        return;
      }

      const current = t.scrollLeft;

      // Abort if external interaction (drag/swipe/wheel) perturbed position.
      if (Math.abs(current - lastSet) > EXTERNAL_SCROLL_TOLERANCE_PX) {
        this.#cancelAnimation();
        return;
      }

      const distance = this.#animationTarget - current;
      if (Math.abs(distance) < ANIMATION_FINISH_THRESHOLD) {
        t.scrollLeft = this.#animationTarget;
        // If we landed on a clone (wrap animation), silently teleport to its
        // real counterpart. currentIndex was set to the wrap target by
        // scrollToIndex, so it already matches.
        this.#teleportFromWrapZone();
        this.#cancelAnimation();
        return;
      }

      const next = current + distance * ANIMATION_APPROACH_RATE;
      t.scrollLeft = next;
      lastSet = next;
      this.#animationFrame = requestAnimationFrame(tick);
    };

    this.#animationFrame = requestAnimationFrame(tick);
  }

  #suspendNativeScrollEffects() {
    const track = this.#trackElement;
    if (track) {
      track.style.scrollSnapType = "none";
      track.style.scrollBehavior = "auto";
    }
  }

  #restoreNativeScrollEffects() {
    const track = this.#trackElement;
    if (track) {
      track.style.scrollSnapType = "";
      track.style.scrollBehavior = "";
    }
  }

  #cancelAnimation() {
    if (this.#animationFrame !== null) {
      cancelAnimationFrame(this.#animationFrame);
      this.#animationFrame = null;
    }

    this.#restoreNativeScrollEffects();
    this.#programmaticScroll = false;
  }

  get items() {
    return this.args.data.items || [];
  }

  get isSingle() {
    return this.items.length < 2;
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

  get showDots() {
    return this.items.length <= MAX_DOTS;
  }

  get counterText() {
    return `${this.currentIndex + 1} / ${this.items.length}`;
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

  // For directional navigation (prev/next button, arrow key) that crosses the
  // wrap boundary, return the adjacent clone instead of the real destination
  // slide so the carousel animates one slide-width to it. The rAF's finish
  // branch teleports to the real counterpart afterwards.
  #wrapClone(index, direction) {
    if (
      direction === "next" &&
      this.currentIndex === this.lastIndex &&
      index === 0
    ) {
      return this.#clones.get("first");
    }

    if (
      direction === "prev" &&
      this.currentIndex === 0 &&
      index === this.lastIndex
    ) {
      return this.#clones.get("last");
    }

    return null;
  }

  @action
  scrollToIndex(index, direction = null) {
    const element =
      this.#wrapClone(index, direction) || this.#slides.get(index);
    const track = this.#trackElement;
    if (!element || !track) {
      return;
    }

    this.currentIndex = index;
    const target = this.#computeTargetScrollLeft(element);
    if (Math.abs(track.scrollLeft - target) < 1) {
      return;
    }

    this.#programmaticScroll = true;
    this.#animateScrollTo(target);
  }

  #navigateByKey(direction) {
    const goNext = (direction === "right") === (this.#trackDirection === 1);
    this.scrollToIndex(
      goNext ? this.nextIndex : this.prevIndex,
      goNext ? "next" : "prev"
    );
  }

  @action
  onKeyDown(event) {
    if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") {
      return;
    }

    event.preventDefault();
    const direction = event.key === "ArrowLeft" ? "left" : "right";
    throttle(this, this.#navigateByKey, direction, KEYBOARD_THROTTLE_MS);
  }

  <template>
    <div
      class={{concatClass
        "d-image-carousel"
        (if @data.mode (concat "d-image-carousel--" @data.mode))
        (if this.isSingle "d-image-carousel--single")
      }}
    >
      <div
        {{this.setupTrack}}
        {{on "keydown" this.onKeyDown}}
        tabindex="0"
        class="d-image-carousel__track"
      >
        {{#unless this.isSingle}}
          <div
            {{this.registerClone "last"}}
            inert
            aria-hidden="true"
            style={{getAspectRatio this.lastItem.width this.lastItem.height}}
            class="d-image-carousel__slide d-image-carousel__slide--clone"
          >
            {{this.lastCloneNode}}
          </div>
        {{/unless}}

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

        {{#unless this.isSingle}}
          <div
            {{this.registerClone "first"}}
            inert
            aria-hidden="true"
            style={{getAspectRatio this.firstItem.width this.firstItem.height}}
            class="d-image-carousel__slide d-image-carousel__slide--clone"
          >
            {{this.firstCloneNode}}
          </div>
        {{/unless}}
      </div>

      {{#unless this.isSingle}}
        <div class="d-image-carousel__controls">
          <DButton
            @action={{fn this.scrollToIndex this.prevIndex "prev"}}
            @icon="chevron-left"
            @title="carousel.previous"
            aria-label={{i18n "carousel.previous"}}
            class="btn-flat d-image-carousel__nav d-image-carousel__nav--prev"
          />

          {{#if this.showDots}}
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
            <span class="d-image-carousel__counter">{{this.counterText}}</span>
          {{/if}}

          <DButton
            @action={{fn this.scrollToIndex this.nextIndex "next"}}
            @icon="chevron-right"
            @title="carousel.next"
            aria-label={{i18n "carousel.next"}}
            class="btn-flat d-image-carousel__nav d-image-carousel__nav--next"
          />
        </div>
      {{/unless}}
    </div>
  </template>
}
