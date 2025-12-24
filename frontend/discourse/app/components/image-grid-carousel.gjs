import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { helper } from "@ember/component/helper";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { cancel } from "@ember/runloop";
import { modifier } from "ember-modifier";
import icon from "discourse/helpers/d-icon";
import debounce from "discourse/lib/debounce";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

const plusOne = helper(([val]) => val + 1);

const DEBOUNCE_MS = 30;
const HYSTERESIS_FACTOR = 0.7;
const SCROLLEND_FALLBACK_MS = 500;

/**
 * @typedef {Object} ImageGridCarouselItem
 * @property {HTMLElement} element
 * @property {HTMLImageElement} img
 * @property {number} width
 * @property {number} height
 */

/**
 * @component image-grid-carousel
 * @param {Object} @data
 * @param {Array<ImageGridCarouselItem>} @data.items
 * @param {string} @data.mode
 */
export default class ImageGridCarousel extends Component {
  /**
   * @type {number}
   */
  @tracked currentIndex = 0;

  /**
   * @type {boolean}
   */
  @tracked isProgrammaticScroll = false;

  /**
   * @type {HTMLElement|null}
   */
  trackElement = null;

  /**
   * @type {ReturnType<typeof modifier>}
   */
  mountItem = modifier((element, [itemElement]) => {
    element.appendChild(itemElement);
  });

  /**
   * @type {ReturnType<typeof modifier>}
   */
  setupTrack = modifier((element) => {
    this.trackElement = element;

    const slides = element.querySelectorAll(".d-image-carousel__slide");
    const ratios = new Map();

    const onScrollEnd = () => {
      if (this.#scrollEndFallbackTimer) {
        clearTimeout(this.#scrollEndFallbackTimer);
        this.#scrollEndFallbackTimer = null;
      }
      this.isProgrammaticScroll = false;
    };

    element.addEventListener("scrollend", onScrollEnd);

    const observer = new IntersectionObserver(
      (entries) => {
        if (this.isProgrammaticScroll) {
          return;
        }

        entries.forEach((entry) => {
          ratios.set(entry.target, entry.intersectionRatio);
        });

        const currentScroll = element.scrollLeft;
        const maxScroll = element.scrollWidth - element.offsetWidth;

        let bestIndex = this.currentIndex;
        let minDiff = Infinity;

        slides.forEach((slide, index) => {
          const ratio = ratios.get(slide) || 0;
          if (ratio > 0) {
            // Calculate where this slide *wants* to be scrolled to in order to be centered
            const idealScroll =
              slide.offsetLeft +
              slide.offsetWidth / 2 -
              element.offsetWidth / 2;

            // Clamp to actual possible scroll range so boundaries (start/end) work correctly
            const clampedTarget = Math.max(0, Math.min(idealScroll, maxScroll));

            let diff = Math.abs(clampedTarget - currentScroll);

            // Selection Hysteresis: Bias the calculation to favor the current slide.
            // Other slides must be significantly closer to "win" focus. Dividing by
            // HYSTERESIS_FACTOR (0.7) means they need ~43% less distance to take over.
            if (index !== this.currentIndex) {
              diff = diff / HYSTERESIS_FACTOR;
            }

            if (diff < minDiff) {
              minDiff = diff;
              bestIndex = index;
            }
          }
        });

        this.#debounceTimer = debounce(
          this,
          this.updateActiveIndex,
          bestIndex,
          DEBOUNCE_MS
        );
      },
      {
        root: element,
        threshold: [0, 0.25, 0.5, 1],
      }
    );

    slides.forEach((slide) => observer.observe(slide));

    return () => {
      observer.disconnect();
      element.removeEventListener("scrollend", onScrollEnd);

      if (this.#debounceTimer) {
        cancel(this.#debounceTimer);
        this.#debounceTimer = null;
      }

      if (this.#scrollEndFallbackTimer) {
        clearTimeout(this.#scrollEndFallbackTimer);
        this.#scrollEndFallbackTimer = null;
      }
    };
  });

  /**
   * @type {ReturnType<typeof debounce>|null}
   */
  #debounceTimer = null;

  /**
   * @type {ReturnType<typeof setTimeout>|null}
   */
  #scrollEndFallbackTimer = null;

  @action
  updateActiveIndex(index) {
    if (this.currentIndex !== index && !this.isProgrammaticScroll) {
      this.currentIndex = index;
    }
  }

  /**
   * @returns {Array<ImageGridCarouselItem>}
   */
  get items() {
    return this.args.data.items || [];
  }

  /**
   * @returns {boolean}
   */
  get isSingle() {
    return this.items.length < 2;
  }

  /**
   * @returns {string}
   */
  get scrollBehavior() {
    return window.matchMedia?.("(prefers-reduced-motion: reduce)")?.matches
      ? "auto"
      : "smooth";
  }

  /**
   * @returns {boolean}
   */
  get wrapsAround() {
    return this.args.data.mode === "focus" || this.args.data.mode === "stage";
  }

  /**
   * @returns {number}
   */
  get prevIndex() {
    if (this.currentIndex === 0) {
      return this.wrapsAround ? this.lastIndex : 0;
    }
    return this.currentIndex - 1;
  }

  /**
   * @returns {number}
   */
  get nextIndex() {
    if (this.currentIndex === this.lastIndex) {
      return this.wrapsAround ? 0 : this.lastIndex;
    }
    return this.currentIndex + 1;
  }

  /**
   * @returns {number}
   */
  get lastIndex() {
    return this.items.length - 1;
  }

  /**
   * @returns {boolean}
   */
  get isPrevDisabled() {
    return !this.wrapsAround && this.currentIndex === 0;
  }

  /**
   * @returns {boolean}
   */
  get isNextDisabled() {
    return !this.wrapsAround && this.currentIndex === this.lastIndex;
  }

  /**
   * @param {number} index
   */
  @action
  scrollToIndex(index) {
    const clamped = Math.max(0, Math.min(index, this.items.length - 1));
    const slides = this.trackElement?.querySelectorAll(
      ".d-image-carousel__slide"
    );
    if (slides && slides[clamped]) {
      this.isProgrammaticScroll = true;
      this.currentIndex = clamped;

      // Fallback for browsers that don't support scrollend event (Safari < 17.4)
      if (this.#scrollEndFallbackTimer) {
        clearTimeout(this.#scrollEndFallbackTimer);
      }
      this.#scrollEndFallbackTimer = setTimeout(() => {
        this.isProgrammaticScroll = false;
        this.#scrollEndFallbackTimer = null;
      }, SCROLLEND_FALLBACK_MS);

      slides[clamped].scrollIntoView({
        behavior: this.scrollBehavior,
        block: "nearest",
        inline: "center",
      });
    }
  }

  /**
   * @param {KeyboardEvent} event
   */
  @action
  onKeyDown(event) {
    if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") {
      return;
    }

    const direction =
      getComputedStyle(this.trackElement).direction === "rtl" ? -1 : 1;

    if (event.key === "ArrowLeft") {
      this.scrollToIndex(direction === 1 ? this.prevIndex : this.nextIndex);
    } else {
      this.scrollToIndex(direction === 1 ? this.nextIndex : this.prevIndex);
    }
  }

  <template>
    <div
      class="d-image-carousel --{{@data.mode}}
        {{if this.isSingle 'd-image-carousel__carousel--single'}}"
    >
      <div
        class="d-image-carousel__track"
        tabindex="0"
        {{this.setupTrack}}
        {{on "keydown" this.onKeyDown}}
      >
        {{#each this.items as |item index|}}
          <div
            class="d-image-carousel__slide
              {{if (eq this.currentIndex index) 'is-active'}}"
            data-index={{index}}
            {{this.mountItem item.element}}
          >
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
            disabled={{this.isPrevDisabled}}
            {{on "click" (fn this.scrollToIndex this.prevIndex)}}
          >
            {{icon "chevron-left"}}
          </button>

          <div class="d-image-carousel__dots">
            {{#each this.items as |item index|}}
              <button
                type="button"
                class="d-image-carousel__dot
                  {{if (eq this.currentIndex index) 'active'}}"
                aria-label={{i18n "carousel.go_to_slide" index=(plusOne index)}}
                aria-current={{if (eq this.currentIndex index) "true" "false"}}
                {{on "click" (fn this.scrollToIndex index)}}
              ></button>
            {{/each}}
          </div>

          <button
            type="button"
            class="d-image-carousel__nav d-image-carousel__nav--next"
            title={{i18n "carousel.next"}}
            aria-label={{i18n "carousel.next"}}
            disabled={{this.isNextDisabled}}
            {{on "click" (fn this.scrollToIndex this.nextIndex)}}
          >
            {{icon "chevron-right"}}
          </button>
        </div>
      {{/unless}}
    </div>
  </template>
}
