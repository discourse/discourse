import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface LayoutGridThumbnailSignature {
  Element: SVGSVGElement;
}

/** Palette thumbnail for an explicitly placed grid layout. */
const LayoutGridThumbnail: TemplateOnlyComponent<LayoutGridThumbnailSignature> =
  <template>
    <svg viewBox="0 0 120 80" fill="none" aria-hidden="true" ...attributes>
      <rect
        x="14"
        y="14"
        width="58"
        height="24"
        rx="3"
        fill="var(--primary-low)"
      />
      <rect
        x="78"
        y="14"
        width="28"
        height="52"
        rx="3"
        fill="var(--primary-low)"
      />
      <rect
        x="14"
        y="44"
        width="27"
        height="22"
        rx="3"
        fill="var(--primary-low)"
      />
      <rect
        x="47"
        y="44"
        width="25"
        height="22"
        rx="3"
        fill="var(--primary-low)"
      />
    </svg>
  </template>;

export default LayoutGridThumbnail;
