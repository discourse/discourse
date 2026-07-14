import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface CtaBannerThumbnailSignature {
  // Root element type (enables ...attributes type checking)
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `cta-banner` block: a banner with heading and button. */
const CtaBannerThumbnail: TemplateOnlyComponent<CtaBannerThumbnailSignature> =
  <template>
    <svg viewBox="0 0 120 80" fill="none" aria-hidden="true" ...attributes>
      <rect
        x="12"
        y="16"
        width="96"
        height="48"
        rx="6"
        fill="var(--tertiary-low)"
      />
      <rect x="24" y="26" width="50" height="7" rx="3" fill="var(--primary)" />
      <rect
        x="24"
        y="38"
        width="64"
        height="4"
        rx="2"
        fill="var(--primary-medium)"
      />
      <rect
        x="24"
        y="48"
        width="34"
        height="10"
        rx="5"
        fill="var(--tertiary)"
      />
    </svg>
  </template>;

export default CtaBannerThumbnail;
