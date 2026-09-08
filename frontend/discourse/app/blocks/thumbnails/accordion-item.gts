import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface AccordionItemThumbnailSignature {
  // Root element type (enables ...attributes type checking)
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `accordion-item` block: a single expanded row. */
const AccordionItemThumbnail: TemplateOnlyComponent<AccordionItemThumbnailSignature> =
  <template>
    <svg aria-hidden="true" fill="none" viewBox="0 0 120 80" ...attributes>
      <rect
        fill="var(--primary-low)"
        height="18"
        rx="4"
        width="88"
        x="16"
        y="20"
      />
      <rect
        fill="var(--primary-medium)"
        height="5"
        rx="2"
        width="44"
        x="24"
        y="27"
      />
      <path
        d="M92 27 L96 31 L100 27"
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
        x="24"
        y="46"
      />
      <rect
        fill="var(--primary-low-mid)"
        height="4"
        rx="2"
        width="60"
        x="24"
        y="54"
      />
      <rect
        fill="var(--primary-low-mid)"
        height="4"
        rx="2"
        width="40"
        x="24"
        y="62"
      />
    </svg>
  </template>;

export default AccordionItemThumbnail;
