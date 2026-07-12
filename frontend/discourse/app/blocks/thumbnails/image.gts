import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface ImageThumbnailSignature {
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `image` block: a framed picture with sun and hills. */
const ImageThumbnail: TemplateOnlyComponent<ImageThumbnailSignature> =
  <template>
    <svg viewBox="0 0 120 80" fill="none" aria-hidden="true" ...attributes>
      <rect
        x="14"
        y="14"
        width="92"
        height="52"
        rx="5"
        fill="var(--primary-low)"
        stroke="var(--primary-low-mid)"
        stroke-width="1.5"
      />
      <circle cx="40" cy="31" r="7" fill="var(--tertiary)" />
      <path
        d="M18 62 L44 40 L60 54 L74 44 L102 62 Z"
        fill="var(--primary-medium)"
      />
    </svg>
  </template>;

export default ImageThumbnail;
