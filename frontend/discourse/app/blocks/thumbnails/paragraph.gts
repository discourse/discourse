import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface ParagraphThumbnailSignature {
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `paragraph` block: a block of body-text lines. */
const ParagraphThumbnail: TemplateOnlyComponent<ParagraphThumbnailSignature> =
  <template>
    <svg viewBox="0 0 120 80" fill="none" aria-hidden="true" ...attributes>
      <rect
        x="16"
        y="20"
        width="88"
        height="5"
        rx="2"
        fill="var(--primary-low-mid)"
      />
      <rect
        x="16"
        y="30"
        width="82"
        height="5"
        rx="2"
        fill="var(--primary-low-mid)"
      />
      <rect
        x="16"
        y="40"
        width="86"
        height="5"
        rx="2"
        fill="var(--primary-low-mid)"
      />
      <rect
        x="16"
        y="50"
        width="74"
        height="5"
        rx="2"
        fill="var(--primary-low-mid)"
      />
      <rect
        x="16"
        y="60"
        width="44"
        height="5"
        rx="2"
        fill="var(--primary-low-mid)"
      />
    </svg>
  </template>;

export default ParagraphThumbnail;
