import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface CtaBannerThumbnailSignature {
  // Root element type (enables ...attributes type checking)
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `cta-banner` block: a banner with heading and button. */
const CtaBannerThumbnail: TemplateOnlyComponent<CtaBannerThumbnailSignature> =
  <template>
    <svg aria-hidden="true" fill="none" viewBox="0 0 120 80" ...attributes>
      <rect
        fill="var(--tertiary-low)"
        height="48"
        rx="6"
        width="96"
        x="12"
        y="16"
      />
      <rect fill="var(--primary)" height="7" rx="3" width="50" x="24" y="26" />
      <rect
        fill="var(--primary-medium)"
        height="4"
        rx="2"
        width="64"
        x="24"
        y="38"
      />
      <rect
        fill="var(--tertiary)"
        height="10"
        rx="5"
        width="34"
        x="24"
        y="48"
      />
    </svg>
  </template>;

export default CtaBannerThumbnail;
