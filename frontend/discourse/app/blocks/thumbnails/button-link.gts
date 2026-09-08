import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface ButtonLinkThumbnailSignature {
  // Root element type (enables ...attributes type checking)
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `button-link` block: a single pill button. */
const ButtonLinkThumbnail: TemplateOnlyComponent<ButtonLinkThumbnailSignature> =
  <template>
    <svg aria-hidden="true" fill="none" viewBox="0 0 120 80" ...attributes>
      <rect
        fill="var(--tertiary)"
        height="20"
        rx="10"
        width="52"
        x="34"
        y="30"
      />
      <rect
        fill="var(--secondary)"
        height="4"
        rx="2"
        width="28"
        x="46"
        y="38"
      />
    </svg>
  </template>;

export default ButtonLinkThumbnail;
