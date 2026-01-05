import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { helper } from "@ember/component/helper";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { cancel } from "@ember/runloop";
import { htmlSafe } from "@ember/template";
import { modifier } from "ember-modifier";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import debounce from "discourse/lib/debounce";
import discourseLater from "discourse/lib/later";
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
  slides = [];

  registerSlide = modifier((element, [index]) => {
    this.slides[index] = element;
    return () => {
      this.slides[index] = null;
    };
  });

  mountItem = modifier((element, [itemElement]) => {
    element.appendChild(itemElement);
  });

  setupTrack = modifier((element) => {
    this.trackElement = element;
    const ratios = new Map();

    const onScrollEnd = () => {
      if (this.#scrollEndFallbackTimer) {
        cancel(this.#scrollEndFallbackTimer);
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

        this.slides.forEach((slide, index) => {
          const ratio = ratios.get(slide) || 0;
          if (ratio > 0) {
            const idealScroll =
              slide.offsetLeft +
              slide.offsetWidth / 2 -
              element.clientWidth / 2;
            const clampedTarget = Math.max(0, Math.min(idealScroll, maxScroll));
            let diff = Math.abs(clampedTarget - currentScroll);

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

    this.slides.forEach((slide) => observer.observe(slide));

    return () => {
      observer.disconnect();
      element.removeEventListener("scrollend", onScrollEnd);
      cancel(this.#debounceTimer);
      cancel(this.#scrollEndFallbackTimer);
    };
  });

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
    const slide = this.slides[clamped];
    if (slide) {
      if (this.#debounceTimer) {
        cancel(this.#debounceTimer);
        this.#debounceTimer = null;
      }

      this.#scrollGeneration++;
      const thisGeneration = this.#scrollGeneration;
      this.#activeScrollGeneration = thisGeneration;
      this.currentIndex = clamped;

      cancel(this.#scrollEndFallbackTimer);
      this.#scrollEndFallbackTimer = discourseLater(() => {
        if (this.#activeScrollGeneration === thisGeneration) {
          this.#activeScrollGeneration = 0;
        }
      }, SCROLLEND_FALLBACK_MS);

      slide.scrollIntoView({
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
            {{this.mountItem item.element}}
          ></div>
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
