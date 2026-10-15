import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface FeaturedTopicsThumbnailSignature {
  // Root element type (enables ...attributes type checking)
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `featured-topics` block: a highlighted topic over a list. */
const FeaturedTopicsThumbnail: TemplateOnlyComponent<FeaturedTopicsThumbnailSignature> =
  <template>
    <svg aria-hidden="true" fill="none" viewBox="0 0 120 80" ...attributes>
      <rect
        fill="var(--tertiary-low)"
        height="20"
        rx="4"
        width="92"
        x="14"
        y="14"
      />
      <circle cx="24" cy="24" fill="var(--tertiary)" r="5" />
      <rect
        fill="var(--primary-medium)"
        height="6"
        rx="2"
        width="60"
        x="34"
        y="21"
      />

      <circle cx="24" cy="45" fill="var(--primary-low-mid)" r="5" />
      <rect
        fill="var(--primary-low-mid)"
        height="5"
        rx="2"
        width="66"
        x="34"
        y="42"
      />

      <circle cx="24" cy="62" fill="var(--primary-low-mid)" r="5" />
      <rect
        fill="var(--primary-low-mid)"
        height="5"
        rx="2"
        width="52"
        x="34"
        y="59"
      />
    </svg>
  </template>;

export default FeaturedTopicsThumbnail;
