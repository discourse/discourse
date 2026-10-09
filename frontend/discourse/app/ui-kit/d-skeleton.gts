import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { type TrustedHTML, trustHTML } from "@ember/template";
import { eq } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

const DEFAULT_COUNT = 1;

/** A placeholder longer than this reserves space no real content will occupy. */
const MAX_COUNT = 50;

const VARIANTS = ["text", "rect", "circle"] as const;

type SkeletonVariant = (typeof VARIANTS)[number];

/**
 * The dimension custom properties, each paired with the property the stylesheet
 * feeds it to. A value is emitted only if it is valid for that property, which
 * is what stops one from carrying further declarations into the style attribute.
 */
const DIMENSIONS = {
  "--d-skeleton-item-width": "width",
  "--d-skeleton-item-height": "height",
  "--d-skeleton-radius": "border-radius",
} as const;

type DimensionValues = Partial<Record<keyof typeof DIMENSIONS, string>>;

/**
 * Valid for any property, so `CSS.supports` waves them through, but a custom
 * property holding one is guaranteed-invalid rather than the keyword's usual
 * meaning. Rejecting them here keeps the variant's own sizing instead.
 */
const CSS_WIDE_KEYWORDS = new Set([
  "initial",
  "inherit",
  "unset",
  "revert",
  "revert-layer",
]);

function buildDimensionStyle(values: DimensionValues): TrustedHTML | undefined {
  const declarations = Object.entries(values).flatMap(([property, value]) => {
    const target = DIMENSIONS[property as keyof typeof DIMENSIONS];
    return value != null &&
      !CSS_WIDE_KEYWORDS.has(value.trim().toLowerCase()) &&
      CSS.supports(target, value)
      ? [`${property}:${value}`]
      : [];
  });

  return declarations.length ? trustHTML(declarations.join(";")) : undefined;
}

interface DSkeletonSignature {
  Args: {
    count?: number;
    variant?: SkeletonVariant;
    animated?: boolean;
    width?: string;
    height?: string;
    radius?: string;
    size?: string;
    lastLineWidth?: string;
  };
  Element: HTMLDivElement;
}

/**
 * Reusable loading placeholder. Renders one or more shimmer items shaped by
 * `@variant` (a text line, a rectangle, or a circle) and sized to reserve the
 * space the real content will occupy, so revealing the content doesn't shift
 * the surrounding layout.
 *
 * A lone `text` bar takes the inherited line box (`1lh`), matching a real
 * one-line element; stacked text lines drop to ink height (`1em`) spaced one
 * line-height apart, so a paragraph reads as separate lines. Either way the
 * sizing follows the surrounding typography, so a skeleton in a given context
 * (e.g. a heading) needs no hard-coded height or gap. `@lastLineWidth` narrows
 * a multi-line block's final line the way a real paragraph's does.
 *
 * The shimmer comes from the shared `.placeholder-animation` class, which only
 * paints under `prefers-reduced-motion: no-preference`. The items therefore
 * keep a static fill underneath (from the scss) so the placeholder still reads
 * when the animation is suppressed (reduced motion, or `@animated={{false}}`).
 *
 * The placeholder is decorative and the wrapper is `aria-hidden`, so assistive
 * technology sees nothing here. Announcing the load is the caller's half of the
 * contract: mark the region whose content is being replaced `aria-busy` while it
 * resolves. Passing `role="status"` to this component announces nothing on its
 * own, because the wrapper stays hidden; override `aria-hidden` through
 * `...attributes` if the placeholder itself has to be exposed.
 *
 * Adjust it through the custom properties. The theming ones —
 * `--d-skeleton-fill`, `--d-skeleton-shimmer`, `--d-skeleton-duration` and
 * `--d-skeleton-radius` — can be set by a class on the placeholder or scoped from
 * any ancestor, so a container can retint everything inside it. The `circle`
 * variant is the one exception: its radius is what makes it a circle, so it is
 * not themeable from outside. The layout ones,
 * `--d-skeleton-display` and `--d-skeleton-gap`, only take effect on the
 * placeholder itself, so a container cannot relay out a nested one by accident.
 * Keep `--d-skeleton-display` a flex value, since the line rhythm comes from
 * `gap`.
 *
 * The consumer's `...attributes` are forwarded to the wrapper, but `style` is the
 * component's own: it carries the dimensions, so anything passed there is
 * discarded. Use a class.
 */
export default class DSkeleton extends Component<DSkeletonSignature> {
  /**
   * The variant, defaulting to a text line. Stamped on both the wrapper and
   * each item so the scss can key variant-specific defaults off it. An
   * unrecognised value falls back rather than stamping a modifier no rule
   * matches, which would leave an item with none of its variant's sizing.
   */
  get variant(): SkeletonVariant {
    const requested = this.args.variant as SkeletonVariant;
    return VARIANTS.includes(requested) ? requested : "text";
  }

  /**
   * Whether more than one item is stacked, so the scss can treat a stack
   * differently from a lone bar (e.g. stacked text lines drop from a full line
   * box to ink height so they read as separate lines).
   */
  get multiline(): boolean {
    return this.#itemCount > 1;
  }

  /**
   * How many items to render. Coerced and clamped because the count reaches the
   * component from callers that only assert its type: a non-finite value would
   * otherwise render nothing, and an unbounded one would allocate until the tab
   * gave up.
   */
  get #itemCount(): number {
    const requested = Number(this.args.count ?? DEFAULT_COUNT);

    if (!Number.isFinite(requested)) {
      return DEFAULT_COUNT;
    }

    return Math.min(Math.max(1, Math.floor(requested)), MAX_COUNT);
  }

  /** The indices of the placeholder items to render, one per `@count`. */
  get items(): number[] {
    return Array.from({ length: this.#itemCount }, (_, index) => index);
  }

  /**
   * The shared class applied to every item: the base item class, its variant
   * modifier, and the shimmer class when animated.
   */
  get itemClass(): string {
    const classes = ["d-skeleton__item", `d-skeleton__item--${this.variant}`];

    if (this.args.animated ?? true) {
      classes.push("placeholder-animation");
    }

    return classes.join(" ");
  }

  /**
   * The dimensions shared by every item, emitted as inline custom properties
   * (not `width`/`height`/`border-radius` themselves) so the stylesheet owns the
   * property mapping. They sit on the wrapper because they are uniform, and the
   * items inherit them. `@size` is a shorthand that makes a square; explicit
   * `@width`/`@height` win over it. `undefined` when nothing is set, so the
   * variant's scss tokens apply.
   */
  get dimensionStyle(): TrustedHTML | undefined {
    const { width, height, radius, size } = this.args;

    return buildDimensionStyle({
      "--d-skeleton-item-width": width ?? size,
      "--d-skeleton-item-height": height ?? size,
      "--d-skeleton-radius": radius,
    });
  }

  /** Overrides the width of the final line so it tapers like a real paragraph's. */
  get lastLineStyle(): TrustedHTML | undefined {
    return buildDimensionStyle({
      "--d-skeleton-item-width": this.args.lastLineWidth,
    });
  }

  /**
   * The item `@lastLineWidth` applies to, or `-1` when it applies to none. A
   * lone bar is left at full width: it stands in for a whole element, not for
   * the last line of a paragraph.
   */
  get lastLineIndex(): number {
    return this.multiline && this.args.lastLineWidth != null
      ? this.#itemCount - 1
      : -1;
  }

  <template>
    <div
      aria-hidden="true"
      class={{dConcatClass
        "d-skeleton"
        (concat "d-skeleton--" this.variant)
        (if this.multiline "d-skeleton--multiline")
      }}
      ...attributes
      style={{this.dimensionStyle}}
    >
      {{#each this.items key="@index" as |index|}}
        <div
          class={{this.itemClass}}
          style={{if (eq index this.lastLineIndex) this.lastLineStyle}}
        ></div>
      {{/each}}
    </div>
  </template>
}
