import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { modifier } from "ember-modifier";
import icon from "discourse/helpers/d-icon";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

const INTERSECTION_THRESHOLD = 0.6;

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
 * @param {string|null} @data.aspect
 */
export default class ImageGridCarousel extends Component {
  /**
   * @type {number}
   */
  @tracked currentIndex = 0;

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

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          ratios.set(entry.target, entry.intersectionRatio);
        });

        let bestIndex = this.currentIndex;
        let bestRatio = 0;

        slides.forEach((slide, index) => {
          const ratio = ratios.get(slide) || 0;
          if (ratio > bestRatio) {
            bestRatio = ratio;
            bestIndex = index;
          }
        });

        if (
          bestRatio >= INTERSECTION_THRESHOLD &&
          bestIndex !== this.currentIndex
        ) {
          this.currentIndex = bestIndex;
        }
      },
      {
        root: element,
        threshold: [0, 0.25, 0.5, 0.75, 1],
      }
    );

    slides.forEach((slide) => observer.observe(slide));

    return () => {
      observer.disconnect();
    };
  });

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
   * @returns {number}
   */
  get prevIndex() {
    return Math.max(0, this.currentIndex - 1);
  }

  /**
   * @returns {number}
   */
  get nextIndex() {
    return Math.min(this.items.length - 1, this.currentIndex + 1);
  }

  /**
   * @returns {number}
   */
  get lastIndex() {
    return this.items.length - 1;
  }

  /**
   * @param {number} index
   * @returns {string}
   */
  slideAriaLabel(index) {
    return i18n("carousel.go_to_slide", { index: index + 1 });
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
      this.scrollToIndex(this.currentIndex - direction);
    } else {
      this.scrollToIndex(this.currentIndex + direction);
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
            title={{i18n "lightbox.previous"}}
            aria-label={{i18n "lightbox.previous"}}
            disabled={{eq this.currentIndex 0}}
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
                aria-label={{this.slideAriaLabel index}}
                aria-current={{if (eq this.currentIndex index) "true" "false"}}
                {{on "click" (fn this.scrollToIndex index)}}
              ></button>
            {{/each}}
          </div>

          <button
            type="button"
            class="d-image-carousel__nav d-image-carousel__nav--next"
            title={{i18n "lightbox.next"}}
            aria-label={{i18n "lightbox.next"}}
            disabled={{eq this.currentIndex this.lastIndex}}
            {{on "click" (fn this.scrollToIndex this.nextIndex)}}
          >
            {{icon "chevron-right"}}
          </button>
        </div>
      {{/unless}}
    </div>
  </template>
}
