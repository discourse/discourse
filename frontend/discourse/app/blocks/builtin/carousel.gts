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
import type { ChildBlockResult } from "discourse/lib/blocks/-internals/types";
import { isTesting } from "discourse/lib/environment";
import { eq } from "discourse/truth-helpers";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const SCROLL_THROTTLE_MS = 50;
const MAX_DOTS = 10;

interface CarouselSignature {
  Args: {
    children?: ChildBlockResult[];
    showDots?: boolean;
    loop?: boolean;
    perView?: number;
  };
}

/**
 * A carousel: a horizontal, scroll-snapping slideshow whose slides are
 * arbitrary child blocks (a hero, a CTA, a card — anything). On the live page
 * it shows one slide (or `perView` slides) at a time with prev/next controls
 * and dot indicators; native scroll-snap provides touch swiping.
 *
 * In an editing context the same paged track renders, so the live and edit
 * presentations match. The prev/next/dot controls carry a marker that lets
 * in-session editing tooling page the track on a click while keeping the block
 * — and each slide — selectable and editable in place. Slides that are scrolled
 * out of view stay reachable for selection and reordering through the usual
 * child machinery.
 */
@block("carousel", {
  thumbnail: () => import("discourse/blocks/thumbnails/carousel"),
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
export default class Carousel extends Component<CarouselSignature> {
  @tracked currentIndex = 0;

  /**
   * Registers each slide element under its stable key so navigation can scroll
   * to it and the active-slide calculation can measure it. Keying by the
   * entry's stable key (not its index) means a structural edit never collides
   * registrations: each element owns its key, so inserting or removing a slide
   * only registers/unregisters that one — shifted siblings keep their key,
   * element, and entry, and their modifier doesn't even re-run.
   */
  registerSlide = modifier((element: HTMLElement, [key]: [string]) => {
    this.#slides.set(key, element);
    return () => {
      this.#slides.delete(key);
    };
  });

  /**
   * Tracks the scroll position of the viewport and keeps `currentIndex` in
   * sync with the slide nearest the centre, for live dot / counter feedback.
   */
  setupTrack = modifier((element: HTMLElement) => {
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

  /** Slide elements keyed by stable key. */
  #slides = new Map<string, HTMLElement>();

  /**
   * Whether an editing context is active, used to mark the nav controls as
   * page-in-place affordances for in-session editing tooling.
   *
   * @returns Whether an editing context is active.
   */
  get isEditing() {
    return debugHooks.isEditPresentation;
  }

  /**
   * The slide child entries.
   *
   * @returns The carousel's child slides.
   */
  get slides(): ChildBlockResult[] {
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

  /**
   * Dots are shown only for a small slide count.
   *
   * @returns Whether the dot indicators should render.
   */
  get showDots() {
    return (this.args.showDots ?? true) && this.slides.length <= MAX_DOTS;
  }

  /**
   * Per-view slide sizing.
   *
   * @returns The inline custom-property declaration.
   */
  get viewStyle() {
    const perView = Math.max(1, this.args.perView ?? 1);
    return trustHTML(`--d-block-carousel-per-view: ${perView}`);
  }

  get #scrollBehavior(): ScrollBehavior {
    return window.matchMedia?.("(prefers-reduced-motion: reduce)")?.matches
      ? "auto"
      : "smooth";
  }

  @action
  scrollToIndex(index: number) {
    const slide = this.#slides.get(this.slides[index]?.key);
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
  onKeyDown(event: KeyboardEvent) {
    // Only page when the viewport itself (it carries `tabindex="0"`) is the
    // focused element. A key press that bubbles up from editable slide content
    // is left alone, so arrow keys used while editing a slide's text move the
    // caret instead of paging the carousel.
    if (event.target !== event.currentTarget) {
      return;
    }
    if (event.key === "ArrowLeft") {
      event.preventDefault();
      this.scrollToIndex(this.prevIndex);
    } else if (event.key === "ArrowRight") {
      event.preventDefault();
      this.scrollToIndex(this.nextIndex);
    }
  }

  #calculateNearestIndex(track: HTMLElement) {
    const center = track.scrollLeft + track.clientWidth / 2;
    let best = 0;
    let min = Infinity;
    this.slides.forEach((child, index) => {
      const slide = this.#slides.get(child.key);
      if (!slide) {
        return;
      }
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
    {{! The same paged track renders live and in an editing context, so the two
        presentations match. In an editing context the nav controls carry a
        data attribute the editing tooling reads to let their clicks page the
        track instead of treating them as a block selection; the attribute is
        omitted on the live page. The root also carries a marker so the tooling
        can locate this carousel from one of its controls (walking from a
        control to the root, then to the marked viewport). }}
    <div
      class="d-block-carousel"
      style={{this.viewStyle}}
      data-wf-carousel={{if this.isEditing "true"}}
    >
      {{! In an editing context the viewport is marked as the drop container so
          in-session editing tooling projects drops onto the slides directly
          (the slides are nested one level below, so the generic
          first-child-wrapper heuristic would otherwise lock onto a single
          slide). The horizontal axis makes the drop indicator read between
          slides, and the slide nouns let the drop messages name positions in
          slide terms. All omitted on the live page. }}
      <div
        class="d-block-carousel__viewport"
        tabindex="0"
        data-wf-drop-container={{if this.isEditing "true"}}
        data-wf-drop-axis={{if this.isEditing "x"}}
        data-wf-child-noun={{if
          this.isEditing
          (i18n "blocks.builtin.carousel.slide_noun")
        }}
        data-wf-child-noun-plural={{if
          this.isEditing
          (i18n "blocks.builtin.carousel.slide_noun_plural")
        }}
        {{this.setupTrack}}
        {{on "keydown" this.onKeyDown}}
      >
        {{#each this.slides key="key" as |child|}}
          <div class="d-block-carousel__slide" {{this.registerSlide child.key}}>
            <child.Component />
          </div>
        {{/each}}
      </div>

      {{#unless this.isSingle}}
        {{! In an editing context the controls strip is marked as excluded from
            drops, so in-session editing tooling neither previews nor lands a
            drop on the nav controls (they page the track instead). Omitted on
            the live page. }}
        <div
          class="d-block-carousel__controls"
          data-wf-drop-exclude={{if this.isEditing "true"}}
        >
          <button
            type="button"
            class="d-block-carousel__nav d-block-carousel__nav--prev"
            aria-label={{i18n "carousel.previous"}}
            data-wf-carousel-nav={{if this.isEditing "true"}}
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
                  data-wf-carousel-nav={{if this.isEditing "true"}}
                  data-wf-carousel-slide-index={{if this.isEditing index}}
                  {{on "click" (fn this.scrollToIndex index)}}
                ></button>
              {{/each}}
            </div>
          {{/if}}

          <button
            type="button"
            class="d-block-carousel__nav d-block-carousel__nav--next"
            aria-label={{i18n "carousel.next"}}
            data-wf-carousel-nav={{if this.isEditing "true"}}
            {{on "click" (fn this.scrollToIndex this.nextIndex)}}
          >
            {{dIcon "chevron-right"}}
          </button>
        </div>
      {{/unless}}
    </div>
  </template>
}
