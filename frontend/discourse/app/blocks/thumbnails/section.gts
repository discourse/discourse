import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface SectionThumbnailSignature {
  Element: SVGSVGElement;
}

const SectionThumbnail: TemplateOnlyComponent<SectionThumbnailSignature> =
  <template>
    <svg aria-hidden="true" fill="none" viewBox="0 0 120 80" ...attributes>
      <rect
        fill="var(--primary-very-low)"
        height="60"
        rx="6"
        stroke="var(--primary-low-mid)"
        stroke-width="2"
        width="100"
        x="10"
        y="10"
      />
      <rect
        fill="var(--secondary)"
        height="40"
        rx="4"
        stroke="var(--primary-low)"
        width="80"
        x="20"
        y="20"
      />
      <rect
        fill="var(--primary-medium)"
        height="5"
        rx="2.5"
        width="42"
        x="29"
        y="30"
      />
      <rect
        fill="var(--primary-low)"
        height="4"
        rx="2"
        width="62"
        x="29"
        y="41"
      />
      <rect
        fill="var(--primary-low)"
        height="4"
        rx="2"
        width="50"
        x="29"
        y="49"
      />
    </svg>
  </template>;

export default SectionThumbnail;
