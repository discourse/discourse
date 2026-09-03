import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface LayoutRowThumbnailSignature {
  Element: SVGSVGElement;
}

/** Palette thumbnail for a horizontal row layout. */
const LayoutRowThumbnail: TemplateOnlyComponent<LayoutRowThumbnailSignature> =
  <template>
    <svg viewBox="0 0 120 80" fill="none" aria-hidden="true" ...attributes>
      <rect
        x="14"
        y="16"
        width="25"
        height="48"
        rx="3"
        fill="var(--primary-low)"
      />
      <rect
        x="47.5"
        y="16"
        width="25"
        height="48"
        rx="3"
        fill="var(--primary-low)"
      />
      <rect
        x="81"
        y="16"
        width="25"
        height="48"
        rx="3"
        fill="var(--primary-low)"
      />
    </svg>
  </template>;

export default LayoutRowThumbnail;
