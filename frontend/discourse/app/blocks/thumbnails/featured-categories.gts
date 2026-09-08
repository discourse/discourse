import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface FeaturedCategoriesThumbnailSignature {
  // Root element type (enables ...attributes type checking)
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `featured-categories` block: a grid of category chips. */
const FeaturedCategoriesThumbnail: TemplateOnlyComponent<FeaturedCategoriesThumbnailSignature> =
  <template>
    <svg aria-hidden="true" fill="none" viewBox="0 0 120 80" ...attributes>
      <rect
        fill="var(--primary-low)"
        height="24"
        rx="4"
        width="40"
        x="16"
        y="18"
      />
      <rect fill="var(--tertiary)" height="14" rx="2" width="6" x="21" y="23" />
      <rect
        fill="var(--primary-medium)"
        height="4"
        rx="2"
        width="20"
        x="31"
        y="27"
      />

      <rect
        fill="var(--primary-low)"
        height="24"
        rx="4"
        width="40"
        x="64"
        y="18"
      />
      <rect fill="var(--love)" height="14" rx="2" width="6" x="69" y="23" />
      <rect
        fill="var(--primary-medium)"
        height="4"
        rx="2"
        width="20"
        x="79"
        y="27"
      />

      <rect
        fill="var(--primary-low)"
        height="24"
        rx="4"
        width="40"
        x="16"
        y="46"
      />
      <rect fill="var(--success)" height="14" rx="2" width="6" x="21" y="51" />
      <rect
        fill="var(--primary-medium)"
        height="4"
        rx="2"
        width="20"
        x="31"
        y="55"
      />

      <rect
        fill="var(--primary-low)"
        height="24"
        rx="4"
        width="40"
        x="64"
        y="46"
      />
      <rect
        fill="var(--primary-medium)"
        height="14"
        rx="2"
        width="6"
        x="69"
        y="51"
      />
      <rect
        fill="var(--primary-medium)"
        height="4"
        rx="2"
        width="20"
        x="79"
        y="55"
      />
    </svg>
  </template>;

export default FeaturedCategoriesThumbnail;
