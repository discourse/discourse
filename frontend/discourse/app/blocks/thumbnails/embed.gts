import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface EmbedThumbnailSignature {
  // Root element type (enables ...attributes type checking)
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `embed` block: a framed area with a code glyph. */
const EmbedThumbnail: TemplateOnlyComponent<EmbedThumbnailSignature> =
  <template>
    <svg viewBox="0 0 120 80" fill="none" aria-hidden="true" ...attributes>
      <rect
        x="18"
        y="16"
        width="84"
        height="48"
        rx="6"
        fill="var(--primary-low)"
        stroke="var(--primary-low-mid)"
        stroke-width="1.5"
      />
      <path
        d="M52 31 L43 40 L52 49"
        stroke="var(--tertiary)"
        stroke-width="3"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
      <path
        d="M68 31 L77 40 L68 49"
        stroke="var(--tertiary)"
        stroke-width="3"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
      <line
        x1="62"
        y1="30"
        x2="58"
        y2="50"
        stroke="var(--tertiary)"
        stroke-width="3"
        stroke-linecap="round"
      />
    </svg>
  </template>;

export default EmbedThumbnail;
