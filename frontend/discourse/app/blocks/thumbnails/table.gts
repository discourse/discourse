import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface TableThumbnailSignature {
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `table` block: a grid with a header row. */
const TableThumbnail: TemplateOnlyComponent<TableThumbnailSignature> =
  <template>
    <svg aria-hidden="true" fill="none" viewBox="0 0 120 80" ...attributes>
      <rect
        fill="var(--secondary)"
        height="48"
        rx="4"
        stroke="var(--primary-low-mid)"
        stroke-width="1.5"
        width="92"
        x="14"
        y="16"
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
        fill="var(--primary-medium)"
        height="4"
        rx="2"
        width="16"
        x="20"
        y="21"
      />
      <rect
        fill="var(--primary-medium)"
        height="4"
        rx="2"
        width="16"
        x="50"
        y="21"
      />
      <rect
        fill="var(--primary-medium)"
        height="4"
        rx="2"
        width="16"
        x="80"
        y="21"
      />
    </svg>
  </template>;

export default TableThumbnail;
