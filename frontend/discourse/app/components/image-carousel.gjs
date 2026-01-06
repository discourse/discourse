import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { helper } from "@ember/component/helper";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { cancel, throttle } from "@ember/runloop";
import { htmlSafe } from "@ember/template";
import { modifier } from "ember-modifier";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import discourseLater from "discourse/lib/later";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

const plusOne = helper(([val]) => val + 1);
const getAspectRatio = helper(([width, height]) => {
  const w = Math.max(1, Math.abs(parseInt(width, 10)) || 1);
  const h = Math.max(1, Math.abs(parseInt(height, 10)) || 1);
  return htmlSafe(`aspect-ratio: ${w} / ${h}`);
});

const FALLBACK_TIMEOUT_MS = 1000;
const KEYBOARD_THROTTLE_MS = 150;
const SCROLL_THROTTLE_MS = 50;
const MAX_DOTS = 10;

export default class ImageCarousel extends Component {
  @tracked currentIndex = 0;

  registerSlide = modifier((element, [index]) => {
    this.#slides.set(index, element);
    return () => {
      this.#slides.delete(index);
    };
  });

  setupTrack = modifier((element) => {
    this.#trackDirection =
      getComputedStyle(element).direction === "rtl" ? -1 : 1;

    const onScroll = () => {
      if (!this.#isNavigating) {
        throttle(this, this.#updateIndexFromScroll, element, SCROLL_THROTTLE_MS);
      }
    };

    const onScrollEnd = () => {
      if (this.#isNavigating) {
        this.#endNavigation();
      } else {
        this.currentIndex = this.#calculateNearestIndex(element);
      }
    };

    element.addEventListener("scroll", onScroll, { passive: true });
    element.addEventListener("scrollend", onScrollEnd);

    return () => {
      element.removeEventListener("scroll", onScroll);
      element.removeEventListener("scrollend", onScrollEnd);
      cancel(this.#fallbackTimer);
    };
  });

  #isNavigating = false;
  #fallbackTimer = null;
  #trackDirection = 1;
  #slides = new Map();

  #calculateNearestIndex(track) {
    if (!track) {
      return this.currentIndex;
    }

    const trackCenter = track.scrollLeft + track.clientWidth / 2;
    let bestIndex = 0;
    let minDistance = Infinity;

    this.#slides.forEach((slide, index) => {
      const slideCenter = slide.offsetLeft + slide.offsetWidth / 2;
      const distance = Math.abs(slideCenter - trackCenter);
      if (distance < minDistance) {
        minDistance = distance;
        bestIndex = index;
      }
    });

    return bestIndex;
  }

  #endNavigation() {
    this.#isNavigating = false;
    cancel(this.#fallbackTimer);
  }

  #updateIndexFromScroll(track) {
    const newIndex = this.#calculateNearestIndex(track);
    if (newIndex !== this.currentIndex) {
      this.currentIndex = newIndex;
    }
  }

  get #scrollBehavior() {
    return window.matchMedia?.("(prefers-reduced-motion: reduce)")?.matches
      ? "auto"
      : "smooth";
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

  @action
  scrollToIndex(index) {
    const clamped = Math.max(0, Math.min(index, this.items.length - 1));
    const slide = this.#slides.get(clamped);

    if (!slide) {
      return;
    }

    this.#isNavigating = true;
    this.currentIndex = clamped;

    cancel(this.#fallbackTimer);
    this.#fallbackTimer = discourseLater(() => {
      if (this.#isNavigating) {
        this.#endNavigation();
      }
    }, FALLBACK_TIMEOUT_MS);

    slide.scrollIntoView({
      behavior: this.#scrollBehavior,
      block: "nearest",
      inline: "center",
    });
  }

  #navigateByKey(direction) {
    const index =
      direction === "left"
        ? this.#trackDirection === 1
          ? this.prevIndex
          : this.nextIndex
        : this.#trackDirection === 1
          ? this.nextIndex
          : this.prevIndex;
    this.scrollToIndex(index);
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
        (if @data.mode (concat "--" @data.mode))
        (if this.isSingle "d-image-carousel__carousel--single")
      }}
    >
      <div
        class="d-image-carousel__track"
        tabindex="0"
        {{this.setupTrack}}
        {{on "keydown" this.onKeyDown}}
      >
        {{#each this.items as |item index|}}
          <div
            class={{concatClass
              "d-image-carousel__slide"
              (if (eq this.currentIndex index) "is-active")
            }}
            data-index={{index}}
            style={{getAspectRatio item.width item.height}}
            {{this.registerSlide index}}
          >
            {{item.element}}
          </div>
        {{/each}}
      </div>

      {{#unless this.isSingle}}
        <div class="d-image-carousel__controls">
          <button
            type="button"
            class="d-image-carousel__nav d-image-carousel__nav--prev"
            title={{i18n "carousel.previous"}}
            aria-label={{i18n "carousel.previous"}}
            {{on "click" (fn this.scrollToIndex this.prevIndex)}}
          >
            {{icon "chevron-left"}}
          </button>

          {{#if this.showDots}}
            <div class="d-image-carousel__dots">
              {{#each this.items as |_item index|}}
                <button
                  type="button"
                  class={{concatClass
                    "d-image-carousel__dot"
                    (if (eq this.currentIndex index) "active")
                  }}
                  aria-label={{i18n
                    "carousel.go_to_slide"
                    index=(plusOne index)
                  }}
                  aria-current={{if
                    (eq this.currentIndex index)
                    "true"
                    "false"
                  }}
                  {{on "click" (fn this.scrollToIndex index)}}
                ></button>
              {{/each}}
            </div>
          {{else}}
            <span class="d-image-carousel__counter">{{this.counterText}}</span>
          {{/if}}

          <button
            type="button"
            class="d-image-carousel__nav d-image-carousel__nav--next"
            title={{i18n "carousel.next"}}
            aria-label={{i18n "carousel.next"}}
            {{on "click" (fn this.scrollToIndex this.nextIndex)}}
          >
            {{icon "chevron-right"}}
          </button>
        </div>
      {{/unless}}
    </div>
  </template>
}
