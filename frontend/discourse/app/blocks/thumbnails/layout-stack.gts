import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface LayoutStackThumbnailSignature {
  Element: SVGSVGElement;
}

/** Palette thumbnail for a vertical stack layout. */
const LayoutStackThumbnail: TemplateOnlyComponent<LayoutStackThumbnailSignature> =
  <template>
    <svg viewBox="0 0 120 80" fill="none" aria-hidden="true" ...attributes>
      <rect
        x="20"
        y="12"
        width="80"
        height="14"
        rx="3"
        fill="var(--primary-low)"
      />
      <rect
        x="20"
        y="33"
        width="80"
        height="14"
        rx="3"
        fill="var(--primary-low)"
      />
      <rect
        x="20"
        y="54"
        width="80"
        height="14"
        rx="3"
        fill="var(--primary-low)"
      />
    </svg>
  </template>;

export default LayoutStackThumbnail;
