import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface TableThumbnailSignature {
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `table` block: a grid with a header row. */
const TableThumbnail: TemplateOnlyComponent<TableThumbnailSignature> =
  <template>
    <svg viewBox="0 0 120 80" fill="none" aria-hidden="true" ...attributes>
      <rect
        x="14"
        y="16"
        width="92"
        height="48"
        rx="4"
        fill="var(--secondary)"
        stroke="var(--primary-low-mid)"
        stroke-width="1.5"
      />
      <path
        d="M14 30 H106"
        stroke="var(--primary-low-mid)"
        stroke-width="1.5"
      />
      <path
        d="M14 47 H106 M44 16 V64 M74 16 V64"
        stroke="var(--primary-low)"
        stroke-width="1.5"
      />
      <rect
        x="20"
        y="21"
        width="16"
        height="4"
        rx="2"
        fill="var(--primary-medium)"
      />
      <rect
        x="50"
        y="21"
        width="16"
        height="4"
        rx="2"
        fill="var(--primary-medium)"
      />
      <rect
        x="80"
        y="21"
        width="16"
        height="4"
        rx="2"
        fill="var(--primary-medium)"
      />
    </svg>
  </template>;

export default TableThumbnail;
