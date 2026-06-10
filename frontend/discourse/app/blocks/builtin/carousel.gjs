// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { throttle } from "@ember/runloop";
import { trustHTML } from "@ember/template";
import { modifier } from "ember-modifier";
import { block } from "discourse/blocks";
import { debugHooks } from "discourse/lib/blocks/-internals/debug-hooks";
import { isTesting } from "discourse/lib/environment";
import { eq } from "discourse/truth-helpers";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const SCROLL_THROTTLE_MS = 50;
const MAX_DOTS = 10;

/**
 * A carousel: a horizontal, scroll-snapping slideshow whose slides are
 * arbitrary child blocks (a hero, a CTA, a card — anything). On the live page
 * it shows one slide (or `perView` slides) at a time with prev/next controls
 * and dot indicators; native scroll-snap provides touch swiping.
 *
 * In an editing context the ambient "edit presentation" capability is set, so
 * the carousel instead renders ALL slides stacked — each is a normal child
 * block, selectable and editable in place, and reorderable through the usual
 * child machinery — rather than hiding all but one behind the paged track.
 */
@block("carousel", {
  container: true,
  displayName: "Carousel",
  icon: "images",
  category: "Layout",
  description:
    "A slideshow of blocks, one slide at a time with navigation controls.",
  args: {
    showDots: {
      type: "boolean",
      default: true,
      ui: {
        control: "toggle",
        label: i18n("blocks.builtin.carousel.show_dots"),
      },
    },
    loop: {
      type: "boolean",
      default: true,
      ui: { control: "toggle", label: i18n("blocks.builtin.carousel.loop") },
    },
    perView: {
      type: "number",
      default: 1,
      integer: true,
      min: 1,
      max: 4,
      ui: { label: i18n("blocks.builtin.carousel.per_view") },
    },
  },
})
export default class Carousel extends Component {
  @tracked currentIndex = 0;

  /**
   * Registers each slide element by index so navigation can scroll to it and
   * the active-dot calculation can measure positions.
   */
  registerSlide = modifier((element, [index]) => {
    this.#slides.set(index, element);
    return () => {
      this.#slides.delete(index);
    };
  });

  /**
   * Tracks the scroll position of the viewport and keeps `currentIndex` in
   * sync with the slide nearest the centre, for live dot / counter feedback.
   */
  setupTrack = modifier((element) => {
    const updateIndex = () => {
      const next = this.#calculateNearestIndex(element);
      if (next !== this.currentIndex) {
        this.currentIndex = next;
      }
    };
    const onScroll = () => {
      if (!isTesting()) {
        throttle(this, updateIndex, SCROLL_THROTTLE_MS);
      }
    };
    element.addEventListener("scroll", onScroll, { passive: true });
    return () => element.removeEventListener("scroll", onScroll);
  });
  #slides = new Map();

  /** @returns {boolean} Whether the editor wants all slides revealed. */
  get isEditing() {
    return debugHooks.isEditPresentation;
  }

  /** @returns {Array<Object>} The slide child entries. */
  get slides() {
    return this.args.children ?? [];
  }

  get isSingle() {
    return this.slides.length < 2;
  }

  get lastIndex() {
    return this.slides.length - 1;
  }

  get prevIndex() {
    if (this.currentIndex > 0) {
      return this.currentIndex - 1;
    }
    return this.args.loop ? this.lastIndex : 0;
  }

  get nextIndex() {
    if (this.currentIndex < this.lastIndex) {
      return this.currentIndex + 1;
    }
    return this.args.loop ? 0 : this.lastIndex;
  }

  /** @returns {boolean} Dots are shown only for a small slide count. */
  get showDots() {
    return (this.args.showDots ?? true) && this.slides.length <= MAX_DOTS;
  }

  /** @returns {ReturnType<typeof trustHTML>} Per-view slide sizing. */
  get viewStyle() {
    const perView = Math.max(1, this.args.perView ?? 1);
    return trustHTML(`--d-block-carousel-per-view: ${perView}`);
  }

  get #scrollBehavior() {
    return window.matchMedia?.("(prefers-reduced-motion: reduce)")?.matches
      ? "auto"
      : "smooth";
  }

  @action
  scrollToIndex(index) {
    const slide = this.#slides.get(index);
    if (slide) {
      this.currentIndex = index;
      slide.scrollIntoView({
        behavior: this.#scrollBehavior,
        block: "nearest",
        inline: "start",
      });
    }
  }

  @action
  onKeyDown(event) {
    if (event.key === "ArrowLeft") {
      event.preventDefault();
      this.scrollToIndex(this.prevIndex);
    } else if (event.key === "ArrowRight") {
      event.preventDefault();
      this.scrollToIndex(this.nextIndex);
    }
  }

  #calculateNearestIndex(track) {
    const center = track.scrollLeft + track.clientWidth / 2;
    let best = 0;
    let min = Infinity;
    this.#slides.forEach((slide, index) => {
      const slideCenter = slide.offsetLeft + slide.offsetWidth / 2;
      const distance = Math.abs(slideCenter - center);
      if (distance < min) {
        min = distance;
        best = index;
      }
    });
    return best;
  }

  <template>
    {{#if this.isEditing}}
      {{! Editing: reveal every slide stacked so each child is directly
          selectable, editable, and reorderable through the usual machinery. }}
      <div class="d-block-carousel d-block-carousel--editing">
        {{#each this.slides key="key" as |child index|}}
          <div class="d-block-carousel__slide" data-slide-index={{index}}>
            <child.Component />
          </div>
        {{/each}}
      </div>
    {{else}}
      <div class="d-block-carousel" style={{this.viewStyle}}>
        <div
          class="d-block-carousel__viewport"
          tabindex="0"
          {{this.setupTrack}}
          {{on "keydown" this.onKeyDown}}
        >
          {{#each this.slides key="key" as |child index|}}
            <div class="d-block-carousel__slide" {{this.registerSlide index}}>
              <child.Component />
            </div>
          {{/each}}
        </div>

        {{#unless this.isSingle}}
          <div class="d-block-carousel__controls">
            <button
              type="button"
              class="d-block-carousel__nav d-block-carousel__nav--prev"
              aria-label={{i18n "carousel.previous"}}
              {{on "click" (fn this.scrollToIndex this.prevIndex)}}
            >
              {{dIcon "chevron-left"}}
            </button>

            {{#if this.showDots}}
              <div class="d-block-carousel__dots">
                {{#each this.slides key="key" as |_child index|}}
                  <button
                    type="button"
                    class="d-block-carousel__dot
                      {{if (eq this.currentIndex index) 'is-active'}}"
                    aria-label={{i18n "carousel.go_to_slide" index=index}}
                    aria-current={{if (eq this.currentIndex index) "true"}}
                    {{on "click" (fn this.scrollToIndex index)}}
                  ></button>
                {{/each}}
              </div>
            {{/if}}

            <button
              type="button"
              class="d-block-carousel__nav d-block-carousel__nav--next"
              aria-label={{i18n "carousel.next"}}
              {{on "click" (fn this.scrollToIndex this.nextIndex)}}
            >
              {{dIcon "chevron-right"}}
            </button>
          </div>
        {{/unless}}
      </div>
    {{/if}}
  </template>
}
