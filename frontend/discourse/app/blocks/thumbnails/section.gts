import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface SectionThumbnailSignature {
  Element: SVGSVGElement;
}

const SectionThumbnail: TemplateOnlyComponent<SectionThumbnailSignature> =
  <template>
    <svg viewBox="0 0 120 80" fill="none" aria-hidden="true" ...attributes>
      <rect
        x="10"
        y="10"
        width="100"
        height="60"
        rx="6"
        fill="var(--primary-very-low)"
        stroke="var(--primary-low-mid)"
        stroke-width="2"
      />
      <rect
        x="20"
        y="20"
        width="80"
        height="40"
        rx="4"
        fill="var(--secondary)"
        stroke="var(--primary-low)"
      />
      <rect
        x="29"
        y="30"
        width="42"
        height="5"
        rx="2.5"
        fill="var(--primary-medium)"
      />
      <rect
        x="29"
        y="41"
        width="62"
        height="4"
        rx="2"
        fill="var(--primary-low)"
      />
      <rect
        x="29"
        y="49"
        width="50"
        height="4"
        rx="2"
        fill="var(--primary-low)"
      />
    </svg>
  </template>;

export default SectionThumbnail;
