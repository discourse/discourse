import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface AccordionItemThumbnailSignature {
  // Root element type (enables ...attributes type checking)
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `accordion-item` block: a single expanded row. */
const AccordionItemThumbnail: TemplateOnlyComponent<AccordionItemThumbnailSignature> =
  <template>
    <svg viewBox="0 0 120 80" fill="none" aria-hidden="true" ...attributes>
      <rect
        x="16"
        y="20"
        width="88"
        height="18"
        rx="4"
        fill="var(--primary-low)"
      />
      <rect
        x="24"
        y="27"
        width="44"
        height="5"
        rx="2"
        fill="var(--primary-medium)"
      />
      <path
        d="M92 27 L96 31 L100 27"
        stroke="var(--primary-medium)"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      />

      <rect
        x="24"
        y="46"
        width="72"
        height="4"
        rx="2"
        fill="var(--primary-low-mid)"
      />
      <rect
        x="24"
        y="54"
        width="60"
        height="4"
        rx="2"
        fill="var(--primary-low-mid)"
      />
      <rect
        x="24"
        y="62"
        width="40"
        height="4"
        rx="2"
        fill="var(--primary-low-mid)"
      />
    </svg>
  </template>;

export default AccordionItemThumbnail;
