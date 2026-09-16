import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface FeaturedUsersThumbnailSignature {
  // Root element type (enables ...attributes type checking)
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `featured-users` block: a row of avatars with names. */
const FeaturedUsersThumbnail: TemplateOnlyComponent<FeaturedUsersThumbnailSignature> =
  <template>
    <svg aria-hidden="true" fill="none" viewBox="0 0 120 80" ...attributes>
      <circle cx="24" cy="32" fill="var(--primary-low)" r="10" />
      <rect
        fill="var(--primary-low-mid)"
        height="4"
        rx="2"
        width="18"
        x="15"
        y="48"
      />

      <circle cx="50" cy="32" fill="var(--primary-low)" r="10" />
      <rect
        fill="var(--primary-low-mid)"
        height="4"
        rx="2"
        width="18"
        x="41"
        y="48"
      />

      <circle cx="76" cy="32" fill="var(--primary-low)" r="10" />
      <rect
        fill="var(--primary-low-mid)"
        height="4"
        rx="2"
        width="18"
        x="67"
        y="48"
      />

      <circle cx="102" cy="32" fill="var(--primary-low)" r="10" />
      <rect
        fill="var(--primary-low-mid)"
        height="4"
        rx="2"
        width="18"
        x="93"
        y="48"
      />
    </svg>
  </template>;

export default FeaturedUsersThumbnail;
