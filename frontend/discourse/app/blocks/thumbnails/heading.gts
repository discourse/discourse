import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface HeadingThumbnailSignature {
  // Root element type (enables ...attributes type checking)
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `heading` block: a bold title bar over two lines. */
const HeadingThumbnail: TemplateOnlyComponent<HeadingThumbnailSignature> =
  <template>
    <svg aria-hidden="true" fill="none" viewBox="0 0 120 80" ...attributes>
      <rect fill="var(--primary)" height="12" rx="2" width="64" x="16" y="22" />
      <rect
        fill="var(--primary-low-mid)"
        height="5"
        rx="2"
        width="88"
        x="16"
        y="44"
      />
      <rect
        fill="var(--primary-low-mid)"
        height="5"
        rx="2"
        width="72"
        x="16"
        y="54"
      />
    </svg>
  </template>;

export default HeadingThumbnail;
