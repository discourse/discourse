import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface QuoteThumbnailSignature {
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `quote` block: an accented blockquote with attribution. */
const QuoteThumbnail: TemplateOnlyComponent<QuoteThumbnailSignature> =
  <template>
    <svg aria-hidden="true" fill="none" viewBox="0 0 120 80" ...attributes>
      <rect fill="var(--tertiary)" height="34" rx="2" width="5" x="22" y="20" />
      <rect
        fill="var(--primary-low-mid)"
        height="5"
        rx="2"
        width="60"
        x="36"
        y="24"
      />
      <rect
        fill="var(--primary-low-mid)"
        height="5"
        rx="2"
        width="52"
        x="36"
        y="34"
      />
      <rect
        fill="var(--primary-low-mid)"
        height="5"
        rx="2"
        width="40"
        x="36"
        y="44"
      />
      <rect
        fill="var(--primary-medium)"
        height="4"
        rx="2"
        width="28"
        x="36"
        y="58"
      />
    </svg>
  </template>;

export default QuoteThumbnail;
