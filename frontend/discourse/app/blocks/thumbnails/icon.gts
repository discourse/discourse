import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface IconThumbnailSignature {
  // Root element type (enables ...attributes type checking)
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `icon` block: a single glyph on a medallion. */
const IconThumbnail: TemplateOnlyComponent<IconThumbnailSignature> = <template>
  <svg viewBox="0 0 120 80" fill="none" aria-hidden="true" ...attributes>
    <circle cx="60" cy="40" r="22" fill="var(--tertiary-low)" />
    <path
      d="M60 28 L62.94 35.95 L71.4 36.3 L64.76 41.55 L67.05 49.71 L60 45 L52.95 49.71 L55.24 41.55 L48.6 36.3 L57.06 35.95 Z"
      fill="var(--tertiary)"
    />
  </svg>
</template>;

export default IconThumbnail;
