import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface CategoryBannerThumbnailSignature {
  // Root element type (enables ...attributes type checking)
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `category-banner` block: a banner with a category swatch. */
const CategoryBannerThumbnail: TemplateOnlyComponent<CategoryBannerThumbnailSignature> =
  <template>
    <svg viewBox="0 0 120 80" fill="none" aria-hidden="true" ...attributes>
      <rect
        x="12"
        y="18"
        width="96"
        height="44"
        rx="6"
        fill="var(--primary-low)"
      />
      <rect
        x="24"
        y="28"
        width="12"
        height="24"
        rx="3"
        fill="var(--tertiary)"
      />
      <rect x="44" y="30" width="40" height="7" rx="3" fill="var(--primary)" />
      <rect
        x="44"
        y="43"
        width="52"
        height="4"
        rx="2"
        fill="var(--primary-medium)"
      />
    </svg>
  </template>;

export default CategoryBannerThumbnail;
