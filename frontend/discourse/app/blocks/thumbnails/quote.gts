import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface QuoteThumbnailSignature {
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `quote` block: an accented blockquote with attribution. */
const QuoteThumbnail: TemplateOnlyComponent<QuoteThumbnailSignature> =
  <template>
    <svg viewBox="0 0 120 80" fill="none" aria-hidden="true" ...attributes>
      <rect x="22" y="20" width="5" height="34" rx="2" fill="var(--tertiary)" />
      <rect
        x="36"
        y="24"
        width="60"
        height="5"
        rx="2"
        fill="var(--primary-low-mid)"
      />
      <rect
        x="36"
        y="34"
        width="52"
        height="5"
        rx="2"
        fill="var(--primary-low-mid)"
      />
      <rect
        x="36"
        y="44"
        width="40"
        height="5"
        rx="2"
        fill="var(--primary-low-mid)"
      />
      <rect
        x="36"
        y="58"
        width="28"
        height="4"
        rx="2"
        fill="var(--primary-medium)"
      />
    </svg>
  </template>;

export default QuoteThumbnail;
