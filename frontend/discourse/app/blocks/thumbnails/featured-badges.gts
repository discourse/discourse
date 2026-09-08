import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface FeaturedBadgesThumbnailSignature {
  // Root element type (enables ...attributes type checking)
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `featured-badges` block: rows of recipients, each earning a badge. */
const FeaturedBadgesThumbnail: TemplateOnlyComponent<FeaturedBadgesThumbnailSignature> =
  <template>
    <svg aria-hidden="true" fill="none" viewBox="0 0 120 80" ...attributes>
      {{! Row 1 }}
      <circle cx="16" cy="22" fill="var(--primary-low)" r="7" />
      <rect
        fill="var(--primary-low-mid)"
        height="6"
        rx="3"
        width="44"
        x="28"
        y="19"
      />
      <polygon
        fill="var(--tertiary)"
        points="100,14 107,18 107,26 100,30 93,26 93,18"
      />

      {{! Row 2 }}
      <circle cx="16" cy="40" fill="var(--primary-low)" r="7" />
      <rect
        fill="var(--primary-low-mid)"
        height="6"
        rx="3"
        width="38"
        x="28"
        y="37"
      />
      <polygon
        fill="var(--success)"
        points="100,32 107,36 107,44 100,48 93,44 93,36"
      />

      {{! Row 3 }}
      <circle cx="16" cy="58" fill="var(--primary-low)" r="7" />
      <rect
        fill="var(--primary-low-mid)"
        height="6"
        rx="3"
        width="41"
        x="28"
        y="55"
      />
      <polygon
        fill="var(--love)"
        points="100,50 107,54 107,62 100,66 93,62 93,54"
      />
    </svg>
  </template>;

export default FeaturedBadgesThumbnail;
