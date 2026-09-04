import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface SpacerThumbnailSignature {
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `spacer` block: two blocks with a marked gap. */
const SpacerThumbnail: TemplateOnlyComponent<SpacerThumbnailSignature> =
  <template>
    <svg viewBox="0 0 120 80" fill="none" aria-hidden="true" ...attributes>
      <rect
        x="16"
        y="12"
        width="88"
        height="20"
        rx="4"
        fill="var(--primary-low)"
      />
      <rect
        x="16"
        y="48"
        width="88"
        height="20"
        rx="4"
        fill="var(--primary-low)"
      />
      <line
        x1="24"
        y1="40"
        x2="96"
        y2="40"
        stroke="var(--tertiary)"
        stroke-width="1.5"
        stroke-dasharray="4 4"
      />
      <path
        d="M60 34 L60 46 M56 37 L60 33 L64 37 M56 43 L60 47 L64 43"
        stroke="var(--tertiary)"
        stroke-width="1.5"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
    </svg>
  </template>;

export default SpacerThumbnail;
