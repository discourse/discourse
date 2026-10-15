import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface DividerThumbnailSignature {
  // Root element type (enables ...attributes type checking)
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `divider` block: a rule between two text groups. */
const DividerThumbnail: TemplateOnlyComponent<DividerThumbnailSignature> =
  <template>
    <svg aria-hidden="true" fill="none" viewBox="0 0 120 80" ...attributes>
      <rect
        fill="var(--primary-low-mid)"
        height="4"
        rx="2"
        width="88"
        x="16"
        y="20"
      />
      <rect
        fill="var(--primary-low-mid)"
        height="4"
        rx="2"
        width="70"
        x="16"
        y="28"
      />
      <line
        stroke="var(--primary)"
        stroke-width="2"
        x1="16"
        x2="104"
        y1="41"
        y2="41"
      />
      <rect
        fill="var(--primary-low-mid)"
        height="4"
        rx="2"
        width="80"
        x="16"
        y="50"
      />
      <rect
        fill="var(--primary-low-mid)"
        height="4"
        rx="2"
        width="60"
        x="16"
        y="58"
      />
    </svg>
  </template>;

export default DividerThumbnail;
