import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface FeaturedTagsThumbnailSignature {
  // Root element type (enables ...attributes type checking)
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `featured-tags` block: rows of tag pills. */
const FeaturedTagsThumbnail: TemplateOnlyComponent<FeaturedTagsThumbnailSignature> =
  <template>
    <svg aria-hidden="true" fill="none" viewBox="0 0 120 80" ...attributes>
      <rect
        fill="var(--tertiary-low)"
        height="14"
        rx="7"
        width="30"
        x="18"
        y="24"
      />
      <rect fill="var(--tertiary)" height="4" rx="2" width="18" x="24" y="29" />

      <rect
        fill="var(--tertiary-low)"
        height="14"
        rx="7"
        width="24"
        x="52"
        y="24"
      />
      <rect fill="var(--tertiary)" height="4" rx="2" width="14" x="57" y="29" />

      <rect
        fill="var(--tertiary-low)"
        height="14"
        rx="7"
        width="22"
        x="80"
        y="24"
      />
      <rect fill="var(--tertiary)" height="4" rx="2" width="12" x="85" y="29" />

      <rect
        fill="var(--tertiary-low)"
        height="14"
        rx="7"
        width="22"
        x="18"
        y="44"
      />
      <rect fill="var(--tertiary)" height="4" rx="2" width="12" x="23" y="49" />

      <rect
        fill="var(--tertiary-low)"
        height="14"
        rx="7"
        width="32"
        x="44"
        y="44"
      />
      <rect fill="var(--tertiary)" height="4" rx="2" width="20" x="49" y="49" />
    </svg>
  </template>;

export default FeaturedTagsThumbnail;
