import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface SpacerThumbnailSignature {
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `spacer` block: two blocks with a marked gap. */
const SpacerThumbnail: TemplateOnlyComponent<SpacerThumbnailSignature> =
  <template>
    <svg aria-hidden="true" fill="none" viewBox="0 0 120 80" ...attributes>
      <rect
        fill="var(--primary-low)"
        height="20"
        rx="4"
        width="88"
        x="16"
        y="12"
      />
      <rect
        fill="var(--primary-low)"
        height="20"
        rx="4"
        width="88"
        x="16"
        y="48"
      />
      <line
        stroke="var(--tertiary)"
        stroke-dasharray="4 4"
        stroke-width="1.5"
        x1="24"
        x2="96"
        y1="40"
        y2="40"
      />
      <path
        d="M60 34 L60 46 M56 37 L60 33 L64 37 M56 43 L60 47 L64 43"
        stroke="var(--tertiary)"
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="1.5"
      />
    </svg>
  </template>;

export default SpacerThumbnail;
