import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface StatsThumbnailSignature {
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `stats` block: a row of number tiles. */
const StatsThumbnail: TemplateOnlyComponent<StatsThumbnailSignature> =
  <template>
    <svg aria-hidden="true" fill="none" viewBox="0 0 120 80" ...attributes>
      <rect fill="var(--primary)" height="16" rx="2" width="20" x="20" y="26" />
      <rect
        fill="var(--primary-medium)"
        height="4"
        rx="2"
        width="24"
        x="18"
        y="48"
      />

      <rect
        fill="var(--tertiary)"
        height="16"
        rx="2"
        width="20"
        x="50"
        y="26"
      />
      <rect
        fill="var(--primary-medium)"
        height="4"
        rx="2"
        width="24"
        x="48"
        y="48"
      />

      <rect fill="var(--primary)" height="16" rx="2" width="20" x="80" y="26" />
      <rect
        fill="var(--primary-medium)"
        height="4"
        rx="2"
        width="24"
        x="78"
        y="48"
      />
    </svg>
  </template>;

export default StatsThumbnail;
