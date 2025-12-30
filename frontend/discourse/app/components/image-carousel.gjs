import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { helper } from "@ember/component/helper";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { cancel } from "@ember/runloop";
import { htmlSafe } from "@ember/template";
import { modifier } from "ember-modifier";
import icon from "discourse/helpers/d-icon";
import debounce from "discourse/lib/debounce";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

const plusOne = helper(([val]) => val + 1);
const getAspectRatio = helper(([width, height]) => {
  const w = Math.max(1, Math.abs(parseInt(width, 10)) || 1);
  const h = Math.max(1, Math.abs(parseInt(height, 10)) || 1);
  return htmlSafe(`aspect-ratio: ${w} / ${h}`);
});

const DEBOUNCE_MS = 50;
const HYSTERESIS_FACTOR = 0.7;
const SCROLLEND_FALLBACK_MS = 1000;
const MAX_DOTS = 10;

export default class ImageCarousel extends Component {
  @tracked currentIndex = 0;
  trackElement = null;

  mountItem = modifier((element, [itemElement]) => {
    element.appendChild(itemElement);
  });

  setupTrack = modifier((element) => {
    this.trackElement = element;

    const slides = element.querySelectorAll(".d-image-carousel__slide");
    const ratios = new Map();

    const onScrollEnd = () => {
      if (this.#scrollEndFallbackTimer) {
        clearTimeout(this.#scrollEndFallbackTimer);
        this.#scrollEndFallbackTimer = null;
      }
      this.#activeScrollGeneration = 0;
    };

    element.addEventListener("scrollend", onScrollEnd);

    const observer = new IntersectionObserver(
      (entries) => {
        if (this.#activeScrollGeneration > 0) {
          return;
        }

        entries.forEach((entry) => {
          ratios.set(entry.target, entry.intersectionRatio);
        });

        const currentScroll = element.scrollLeft;
        const maxScroll = element.scrollWidth - element.clientWidth;

        let bestIndex = this.currentIndex;
        let minDiff = Infinity;

        slides.forEach((slide, index) => {
          const ratio = ratios.get(slide) || 0;
          if (ratio > 0) {
            const idealScroll =
              slide.offsetLeft +
              slide.offsetWidth / 2 -
              element.clientWidth / 2;
            const clampedTarget = Math.max(0, Math.min(idealScroll, maxScroll));
            let diff = Math.abs(clampedTarget - currentScroll);

            // Hysteresis: bias toward current slide, others must be significantly closer
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
        threshold: [0, 0.25, 0.5, 0.75, 1],
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

  // Scroll generation counter prevents race conditions with rapid navigation
  #scrollGeneration = 0;
  #activeScrollGeneration = 0;
  #debounceTimer = null;
  #scrollEndFallbackTimer = null;

  @action
  updateActiveIndex(index) {
    if (this.currentIndex !== index && this.#activeScrollGeneration === 0) {
      this.currentIndex = index;
    }
  }

  get items() {
    return this.args.data.items || [];
  }

  get isSingle() {
    return this.items.length < 2;
  }

  get scrollBehavior() {
    return window.matchMedia?.("(prefers-reduced-motion: reduce)")?.matches
      ? "auto"
      : "smooth";
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
    const slides = this.trackElement?.querySelectorAll(
      ".d-image-carousel__slide"
    );
    if (slides && slides[clamped]) {
      if (this.#debounceTimer) {
        cancel(this.#debounceTimer);
        this.#debounceTimer = null;
      }

      this.#scrollGeneration++;
      const thisGeneration = this.#scrollGeneration;
      this.#activeScrollGeneration = thisGeneration;
      this.currentIndex = clamped;

      // Fallback for browsers without scrollend (Safari < 17.4)
      if (this.#scrollEndFallbackTimer) {
        clearTimeout(this.#scrollEndFallbackTimer);
      }
      this.#scrollEndFallbackTimer = setTimeout(() => {
        if (this.#activeScrollGeneration === thisGeneration) {
          this.#activeScrollGeneration = 0;
        }
        this.#scrollEndFallbackTimer = null;
      }, SCROLLEND_FALLBACK_MS);

      slides[clamped].scrollIntoView({
        behavior: this.scrollBehavior,
        block: "nearest",
        inline: "center",
      });
    }
  }

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
            style={{getAspectRatio item.width item.height}}
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
            {{on "click" (fn this.scrollToIndex this.prevIndex)}}
          >
            {{icon "chevron-left"}}
          </button>

          {{#if this.showDots}}
            <div class="d-image-carousel__dots">
              {{#each this.items as |item index|}}
                <button
                  type="button"
                  class="d-image-carousel__dot
                    {{if (eq this.currentIndex index) 'active'}}"
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
