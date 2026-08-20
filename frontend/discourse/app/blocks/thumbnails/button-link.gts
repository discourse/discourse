import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface ButtonLinkThumbnailSignature {
  // Root element type (enables ...attributes type checking)
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `button-link` block: a single pill button. */
const ButtonLinkThumbnail: TemplateOnlyComponent<ButtonLinkThumbnailSignature> =
  <template>
    <svg viewBox="0 0 120 80" fill="none" aria-hidden="true" ...attributes>
      <rect
        x="34"
        y="30"
        width="52"
        height="20"
        rx="10"
        fill="var(--tertiary)"
      />
      <rect
        x="46"
        y="38"
        width="28"
        height="4"
        rx="2"
        fill="var(--secondary)"
      />
    </svg>
  </template>;

export default ButtonLinkThumbnail;
