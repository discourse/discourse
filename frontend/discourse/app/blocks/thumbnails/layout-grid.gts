import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface LayoutGridThumbnailSignature {
  Element: SVGSVGElement;
}

/** Palette thumbnail for an explicitly placed grid layout. */
const LayoutGridThumbnail: TemplateOnlyComponent<LayoutGridThumbnailSignature> =
  <template>
    <svg aria-hidden="true" fill="none" viewBox="0 0 120 80" ...attributes>
      <rect
        fill="var(--primary-low)"
        height="24"
        rx="3"
        width="58"
        x="14"
        y="14"
      />
      <rect
        fill="var(--primary-low)"
        height="52"
        rx="3"
        width="28"
        x="78"
        y="14"
      />
      <rect
        fill="var(--primary-low)"
        height="22"
        rx="3"
        width="27"
        x="14"
        y="44"
      />
      <rect
        fill="var(--primary-low)"
        height="22"
        rx="3"
        width="25"
        x="47"
        y="44"
      />
    </svg>
  </template>;

export default LayoutGridThumbnail;
