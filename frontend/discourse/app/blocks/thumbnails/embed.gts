import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface EmbedThumbnailSignature {
  // Root element type (enables ...attributes type checking)
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `embed` block: a framed area with a code glyph. */
const EmbedThumbnail: TemplateOnlyComponent<EmbedThumbnailSignature> =
  <template>
    <svg aria-hidden="true" fill="none" viewBox="0 0 120 80" ...attributes>
      <rect
        fill="var(--primary-low)"
        height="48"
        rx="6"
        stroke="var(--primary-low-mid)"
        stroke-width="1.5"
        width="84"
        x="18"
        y="16"
      />
      <path
        d="M52 31 L43 40 L52 49"
        stroke="var(--tertiary)"
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="3"
      />
      <path
        d="M68 31 L77 40 L68 49"
        stroke="var(--tertiary)"
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="3"
      />
      <line
        stroke="var(--tertiary)"
        stroke-linecap="round"
        stroke-width="3"
        x1="62"
        x2="58"
        y1="30"
        y2="50"
      />
    </svg>
  </template>;

export default EmbedThumbnail;
