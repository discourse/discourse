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
    <svg aria-hidden="true" fill="none" viewBox="0 0 120 80" ...attributes>
      <rect
        fill="var(--primary-low)"
        height="21"
        rx="3"
        width="24"
        x="14"
        y="16"
      />
      <rect
        fill="var(--primary-low)"
        height="21"
        rx="3"
        width="24"
        x="14"
        y="43"
      />
      <rect
        fill="var(--primary-low)"
        height="48"
        rx="3"
        width="24"
        x="48"
        y="16"
      />
      <rect
        fill="var(--primary-low)"
        height="21"
        rx="3"
        width="24"
        x="82"
        y="16"
      />
      <rect
        fill="var(--primary-low)"
        height="21"
        rx="3"
        width="24"
        x="82"
        y="43"
      />
    </svg>
  </template>;

export default LayoutThumbnail;
