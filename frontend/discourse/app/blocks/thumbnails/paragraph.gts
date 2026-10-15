import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface ParagraphThumbnailSignature {
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `paragraph` block: a block of body-text lines. */
const ParagraphThumbnail: TemplateOnlyComponent<ParagraphThumbnailSignature> =
  <template>
    <svg aria-hidden="true" fill="none" viewBox="0 0 120 80" ...attributes>
      <rect
        fill="var(--primary-low-mid)"
        height="5"
        rx="2"
        width="88"
        x="16"
        y="20"
      />
      <rect
        fill="var(--primary-low-mid)"
        height="5"
        rx="2"
        width="82"
        x="16"
        y="30"
      />
      <rect
        fill="var(--primary-low-mid)"
        height="5"
        rx="2"
        width="86"
        x="16"
        y="40"
      />
      <rect
        fill="var(--primary-low-mid)"
        height="5"
        rx="2"
        width="74"
        x="16"
        y="50"
      />
      <rect
        fill="var(--primary-low-mid)"
        height="5"
        rx="2"
        width="44"
        x="16"
        y="60"
      />
    </svg>
  </template>;

export default ParagraphThumbnail;
