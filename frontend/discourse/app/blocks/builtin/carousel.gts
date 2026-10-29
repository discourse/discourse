import Component from "@glimmer/component";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";
import { debugHooks } from "discourse/lib/blocks/-internals/debug-hooks";
import type { ChildBlockResult } from "discourse/lib/blocks/-internals/types";
import DCarousel from "discourse/ui-kit/d-carousel";
import { i18n } from "discourse-i18n";

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
  category: "layout",
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
  /**
   * Whether an editing context is active, used to mark the nav controls as
   * page-in-place affordances for in-session editing tooling.
   *
   * @returns Whether an editing context is active.
   */
  get isEditing() {
    return debugHooks.isEditPresentation;
  }

  get loop() {
    return this.args.loop ?? true;
  }

  get showDots() {
    return this.args.showDots ?? true;
  }

  /**
   * The slide child entries.
   *
   * @returns The carousel's child slides.
   */
  get slides(): ChildBlockResult[] {
    return this.args.children ?? [];
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

  @action
  dotLabel(index: number) {
    return i18n("carousel.go_to_slide", { index: index + 1 });
  }

  <template>
    {{! The same paged track renders live and in an editing context, so the two
        presentations match. In an editing context the nav controls carry a
        data attribute the editing tooling reads to let their clicks page the
        track instead of treating them as a block selection; the attribute is
        omitted on the live page. The root also carries a marker so the tooling
        can locate this carousel from one of its controls (walking from a
        control to the root, then to the marked viewport). }}
    <DCarousel
      class="d-block-carousel"
      data-wf-carousel={{if this.isEditing "true"}}
      style={{this.viewStyle}}
      @loop={{this.loop}}
      as |carousel|
    >
      {{! In an editing context the viewport is marked as the drop container so
          in-session editing tooling projects drops onto the slides directly
          (the slides are nested one level below, so the generic
          first-child-wrapper heuristic would otherwise lock onto a single
          slide). The horizontal axis makes the drop indicator read between
          slides, and the slide nouns let the drop messages name positions in
          slide terms. All omitted on the live page. }}
      <carousel.Track
        class="d-block-carousel__viewport"
        data-wf-child-noun={{if
          this.isEditing
          (i18n "blocks.builtin.carousel.slide_noun")
        }}
        data-wf-child-noun-plural={{if
          this.isEditing
          (i18n "blocks.builtin.carousel.slide_noun_plural")
        }}
        data-wf-drop-axis={{if this.isEditing "x"}}
        data-wf-drop-container={{if this.isEditing "true"}}
      >
        {{#each this.slides key="key" as |child|}}
          <carousel.Slide class="d-block-carousel__slide" @key={{child.key}}>
            <child.Component />
          </carousel.Slide>
        {{/each}}
      </carousel.Track>

      {{! In an editing context the controls strip is marked as excluded from
          drops, so in-session editing tooling neither previews nor lands a
          drop on the nav controls (they page the track instead). Omitted on
          the live page. }}
      <carousel.Controls
        class="d-block-carousel__controls"
        data-wf-drop-exclude={{if this.isEditing "true"}}
      >
        <carousel.Previous
          class="d-block-carousel__nav d-block-carousel__nav--prev"
          data-wf-carousel-nav={{if this.isEditing "true"}}
          @label={{i18n "carousel.previous"}}
        />

        {{#if this.showDots}}
          <carousel.Dots class="d-block-carousel__dots">
            {{#each this.slides key="key" as |child index|}}
              <carousel.Dot
                class="d-block-carousel__dot"
                data-wf-carousel-nav={{if this.isEditing "true"}}
                data-wf-carousel-slide-index={{if this.isEditing index}}
                @key={{child.key}}
                @label={{this.dotLabel index}}
              />
            {{/each}}
          </carousel.Dots>
        {{/if}}

        <carousel.Next
          class="d-block-carousel__nav d-block-carousel__nav--next"
          data-wf-carousel-nav={{if this.isEditing "true"}}
          @label={{i18n "carousel.next"}}
        />
      </carousel.Controls>
    </DCarousel>
  </template>
}
