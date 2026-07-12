import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface FeaturedBadgesThumbnailSignature {
  // Root element type (enables ...attributes type checking)
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `featured-badges` block: rows of recipients, each earning a badge. */
const FeaturedBadgesThumbnail: TemplateOnlyComponent<FeaturedBadgesThumbnailSignature> =
  <template>
    <svg viewBox="0 0 120 80" fill="none" aria-hidden="true" ...attributes>
      {{! Row 1 }}
      <circle cx="16" cy="22" r="7" fill="var(--primary-low)" />
      <rect
        x="28"
        y="19"
        width="44"
        height="6"
        rx="3"
        fill="var(--primary-low-mid)"
      />
      <polygon
        points="100,14 107,18 107,26 100,30 93,26 93,18"
        fill="var(--tertiary)"
      />

      {{! Row 2 }}
      <circle cx="16" cy="40" r="7" fill="var(--primary-low)" />
      <rect
        x="28"
        y="37"
        width="38"
        height="6"
        rx="3"
        fill="var(--primary-low-mid)"
      />
      <polygon
        points="100,32 107,36 107,44 100,48 93,44 93,36"
        fill="var(--success)"
      />

      {{! Row 3 }}
      <circle cx="16" cy="58" r="7" fill="var(--primary-low)" />
      <rect
        x="28"
        y="55"
        width="41"
        height="6"
        rx="3"
        fill="var(--primary-low-mid)"
      />
      <polygon
        points="100,50 107,54 107,62 100,66 93,62 93,54"
        fill="var(--love)"
      />
    </svg>
  </template>;

export default FeaturedBadgesThumbnail;
