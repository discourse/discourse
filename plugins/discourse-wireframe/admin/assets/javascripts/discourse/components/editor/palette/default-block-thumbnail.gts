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
        class="wireframe-block-thumbnail-default__frame"
        viewBox="0 0 120 80"
        fill="none"
        aria-hidden="true"
      >
        <rect
          x="6"
          y="6"
          width="108"
          height="68"
          rx="9"
          fill="var(--primary-low)"
        />
        <rect
          x="16"
          y="14"
          width="88"
          height="52"
          rx="7"
          fill="var(--secondary)"
          stroke="var(--primary-low-mid)"
          stroke-width="1.5"
        />
        <circle cx="97" cy="59" r="3" fill="var(--tertiary)" />
      </svg>
      <span class="wireframe-block-thumbnail-default__icon">{{dIcon
          @icon
        }}</span>
    </span>
  </template>;

export default DefaultBlockThumbnail;
