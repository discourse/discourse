import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface WelcomeBannerThumbnailSignature {
  // Root element type (enables ...attributes type checking)
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `welcome-banner` block: a greeting above a search input. */
const WelcomeBannerThumbnail: TemplateOnlyComponent<WelcomeBannerThumbnailSignature> =
  <template>
    <svg aria-hidden="true" fill="none" viewBox="0 0 120 80" ...attributes>
      <rect
        fill="var(--tertiary-low)"
        height="56"
        rx="6"
        width="104"
        x="8"
        y="12"
      />
      <rect fill="var(--primary)" height="7" rx="3" width="56" x="32" y="24" />
      <rect
        fill="var(--secondary)"
        height="12"
        rx="6"
        stroke="var(--primary-low-mid)"
        width="72"
        x="24"
        y="42"
      />
      <circle cx="32" cy="48" r="2.5" stroke="var(--primary-medium)" />
    </svg>
  </template>;

export default WelcomeBannerThumbnail;
