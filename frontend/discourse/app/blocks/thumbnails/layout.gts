import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface LayoutThumbnailSignature {
  Element: SVGSVGElement;
}

/**
 * Palette thumbnail for the `layout` block: a mixed arrangement — a tall
 * centre column flanked by columns split into stacked rows. Combining columns
 * and rows says "arranges children into a flexible structure" (stack / row /
 * grid) rather than one fixed shape, and carries no frame or background, so it
 * reads distinctly from the `section` hero and the `table` grid.
 */
const LayoutThumbnail: TemplateOnlyComponent<LayoutThumbnailSignature> =
  <template>
    <svg viewBox="0 0 120 80" fill="none" aria-hidden="true" ...attributes>
      <rect
        x="14"
        y="16"
        width="24"
        height="21"
        rx="3"
        fill="var(--primary-low)"
      />
      <rect
        x="14"
        y="43"
        width="24"
        height="21"
        rx="3"
        fill="var(--primary-low)"
      />
      <rect
        x="48"
        y="16"
        width="24"
        height="48"
        rx="3"
        fill="var(--primary-low)"
      />
      <rect
        x="82"
        y="16"
        width="24"
        height="21"
        rx="3"
        fill="var(--primary-low)"
      />
      <rect
        x="82"
        y="43"
        width="24"
        height="21"
        rx="3"
        fill="var(--primary-low)"
      />
    </svg>
  </template>;

export default LayoutThumbnail;
