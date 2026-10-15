import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface LayoutRowThumbnailSignature {
  Element: SVGSVGElement;
}

/** Palette thumbnail for a horizontal row layout. */
const LayoutRowThumbnail: TemplateOnlyComponent<LayoutRowThumbnailSignature> =
  <template>
    <svg aria-hidden="true" fill="none" viewBox="0 0 120 80" ...attributes>
      <rect
        fill="var(--primary-low)"
        height="48"
        rx="3"
        width="25"
        x="14"
        y="16"
      />
      <rect
        fill="var(--primary-low)"
        height="48"
        rx="3"
        width="25"
        x="47.5"
        y="16"
      />
      <rect
        fill="var(--primary-low)"
        height="48"
        rx="3"
        width="25"
        x="81"
        y="16"
      />
    </svg>
  </template>;

export default LayoutRowThumbnail;
