import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface FeaturedTopicsThumbnailSignature {
  // Root element type (enables ...attributes type checking)
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `featured-topics` block: a highlighted topic over a list. */
const FeaturedTopicsThumbnail: TemplateOnlyComponent<FeaturedTopicsThumbnailSignature> =
  <template>
    <svg viewBox="0 0 120 80" fill="none" aria-hidden="true" ...attributes>
      <rect
        x="14"
        y="14"
        width="92"
        height="20"
        rx="4"
        fill="var(--tertiary-low)"
      />
      <circle cx="24" cy="24" r="5" fill="var(--tertiary)" />
      <rect
        x="34"
        y="21"
        width="60"
        height="6"
        rx="2"
        fill="var(--primary-medium)"
      />

      <circle cx="24" cy="45" r="5" fill="var(--primary-low-mid)" />
      <rect
        x="34"
        y="42"
        width="66"
        height="5"
        rx="2"
        fill="var(--primary-low-mid)"
      />

      <circle cx="24" cy="62" r="5" fill="var(--primary-low-mid)" />
      <rect
        x="34"
        y="59"
        width="52"
        height="5"
        rx="2"
        fill="var(--primary-low-mid)"
      />
    </svg>
  </template>;

export default FeaturedTopicsThumbnail;
