import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface AccordionThumbnailSignature {
  // Root element type (enables ...attributes type checking)
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `accordion` block: stacked rows, the first expanded. */
const AccordionThumbnail: TemplateOnlyComponent<AccordionThumbnailSignature> =
  <template>
    <svg aria-hidden="true" fill="none" viewBox="0 0 120 80" ...attributes>
      <rect
        fill="var(--primary-low)"
        height="16"
        rx="4"
        width="92"
        x="14"
        y="12"
      />
      <rect
        fill="var(--primary-medium)"
        height="4"
        rx="2"
        width="40"
        x="22"
        y="18"
      />
      <path
        d="M94 18 L98 22 L102 18"
        stroke="var(--primary-medium)"
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
      />

      <rect
        fill="var(--primary-low-mid)"
        height="4"
        rx="2"
        width="72"
        x="20"
        y="34"
      />
      <rect
        fill="var(--primary-low-mid)"
        height="4"
        rx="2"
        width="58"
        x="20"
        y="42"
      />

      <rect
        fill="var(--primary-low)"
        height="16"
        rx="4"
        width="92"
        x="14"
        y="52"
      />
      <rect
        fill="var(--primary-medium)"
        height="4"
        rx="2"
        width="40"
        x="22"
        y="58"
      />
      <path
        d="M96 56 L100 60 L96 64"
        stroke="var(--primary-medium)"
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
      />
    </svg>
  </template>;

export default AccordionThumbnail;
