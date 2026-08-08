import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface AccordionThumbnailSignature {
  // Root element type (enables ...attributes type checking)
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `accordion` block: stacked rows, the first expanded. */
const AccordionThumbnail: TemplateOnlyComponent<AccordionThumbnailSignature> =
  <template>
    <svg viewBox="0 0 120 80" fill="none" aria-hidden="true" ...attributes>
      <rect
        x="14"
        y="12"
        width="92"
        height="16"
        rx="4"
        fill="var(--primary-low)"
      />
      <rect
        x="22"
        y="18"
        width="40"
        height="4"
        rx="2"
        fill="var(--primary-medium)"
      />
      <path
        d="M94 18 L98 22 L102 18"
        stroke="var(--primary-medium)"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      />

      <rect
        x="20"
        y="34"
        width="72"
        height="4"
        rx="2"
        fill="var(--primary-low-mid)"
      />
      <rect
        x="20"
        y="42"
        width="58"
        height="4"
        rx="2"
        fill="var(--primary-low-mid)"
      />

      <rect
        x="14"
        y="52"
        width="92"
        height="16"
        rx="4"
        fill="var(--primary-low)"
      />
      <rect
        x="22"
        y="58"
        width="40"
        height="4"
        rx="2"
        fill="var(--primary-medium)"
      />
      <path
        d="M96 56 L100 60 L96 64"
        stroke="var(--primary-medium)"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
    </svg>
  </template>;

export default AccordionThumbnail;
