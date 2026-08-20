import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface DividerThumbnailSignature {
  // Root element type (enables ...attributes type checking)
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `divider` block: a rule between two text groups. */
const DividerThumbnail: TemplateOnlyComponent<DividerThumbnailSignature> =
  <template>
    <svg viewBox="0 0 120 80" fill="none" aria-hidden="true" ...attributes>
      <rect
        x="16"
        y="20"
        width="88"
        height="4"
        rx="2"
        fill="var(--primary-low-mid)"
      />
      <rect
        x="16"
        y="28"
        width="70"
        height="4"
        rx="2"
        fill="var(--primary-low-mid)"
      />
      <line
        x1="16"
        y1="41"
        x2="104"
        y2="41"
        stroke="var(--primary)"
        stroke-width="2"
      />
      <rect
        x="16"
        y="50"
        width="80"
        height="4"
        rx="2"
        fill="var(--primary-low-mid)"
      />
      <rect
        x="16"
        y="58"
        width="60"
        height="4"
        rx="2"
        fill="var(--primary-low-mid)"
      />
    </svg>
  </template>;

export default DividerThumbnail;
