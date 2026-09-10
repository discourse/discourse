import type { TemplateOnlyComponent } from "@ember/component/template-only";
import dIcon from "discourse/ui-kit/helpers/d-icon";

interface DefaultBlockThumbnailSignature {
  /** Placeholder thumbnail presentation data. */
  Args: {
    /** The block's icon ID, rendered in the frame's center. */
    icon: string;
  };
  /** Outer placeholder thumbnail span. */
  Element: HTMLSpanElement;
}

/**
 * The palette thumbnail shown for a block that declares no `thumbnail`. A
 * themed inline-SVG frame — built entirely from theme color tokens, so it
 * adapts to the active color scheme — with the block's own icon centered on
 * top. This keeps blocks without a custom thumbnail reading as designed tiles
 * that stay distinguishable by their icon, rather than collapsing to a lone
 * glyph.
 */
const DefaultBlockThumbnail: TemplateOnlyComponent<DefaultBlockThumbnailSignature> =
  <template>
    <span class="wireframe-block-thumbnail-default" ...attributes>
      <svg
        aria-hidden="true"
        class="wireframe-block-thumbnail-default__frame"
        fill="none"
        viewBox="0 0 120 80"
      >
        <rect
          fill="var(--primary-low)"
          height="68"
          rx="9"
          width="108"
          x="6"
          y="6"
        />
        <rect
          fill="var(--secondary)"
          height="52"
          rx="7"
          stroke="var(--primary-low-mid)"
          stroke-width="1.5"
          width="88"
          x="16"
          y="14"
        />
        <circle cx="97" cy="59" fill="var(--tertiary)" r="3" />
      </svg>
      <span class="wireframe-block-thumbnail-default__icon">{{dIcon
          @icon
        }}</span>
    </span>
  </template>;

export default DefaultBlockThumbnail;
