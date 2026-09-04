import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface FeaturedUsersThumbnailSignature {
  // Root element type (enables ...attributes type checking)
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `featured-users` block: a row of avatars with names. */
const FeaturedUsersThumbnail: TemplateOnlyComponent<FeaturedUsersThumbnailSignature> =
  <template>
    <svg viewBox="0 0 120 80" fill="none" aria-hidden="true" ...attributes>
      <circle cx="24" cy="32" r="10" fill="var(--primary-low)" />
      <rect
        x="15"
        y="48"
        width="18"
        height="4"
        rx="2"
        fill="var(--primary-low-mid)"
      />

      <circle cx="50" cy="32" r="10" fill="var(--primary-low)" />
      <rect
        x="41"
        y="48"
        width="18"
        height="4"
        rx="2"
        fill="var(--primary-low-mid)"
      />

      <circle cx="76" cy="32" r="10" fill="var(--primary-low)" />
      <rect
        x="67"
        y="48"
        width="18"
        height="4"
        rx="2"
        fill="var(--primary-low-mid)"
      />

      <circle cx="102" cy="32" r="10" fill="var(--primary-low)" />
      <rect
        x="93"
        y="48"
        width="18"
        height="4"
        rx="2"
        fill="var(--primary-low-mid)"
      />
    </svg>
  </template>;

export default FeaturedUsersThumbnail;
