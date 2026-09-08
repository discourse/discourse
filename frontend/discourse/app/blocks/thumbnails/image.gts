import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface ImageThumbnailSignature {
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `image` block: a framed picture with sun and hills. */
const ImageThumbnail: TemplateOnlyComponent<ImageThumbnailSignature> =
  <template>
    <svg aria-hidden="true" fill="none" viewBox="0 0 120 80" ...attributes>
      <rect
        fill="var(--primary-low)"
        height="52"
        rx="5"
        stroke="var(--primary-low-mid)"
        stroke-width="1.5"
        width="92"
        x="14"
        y="14"
      />
      <circle cx="40" cy="31" fill="var(--tertiary)" r="7" />
      <path
        d="M18 62 L44 40 L60 54 L74 44 L102 62 Z"
        fill="var(--primary-medium)"
      />
    </svg>
  </template>;

export default ImageThumbnail;
