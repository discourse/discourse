import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface TopicCardThumbnailSignature {
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `topic-card` block: a card with avatar, title and meta. */
const TopicCardThumbnail: TemplateOnlyComponent<TopicCardThumbnailSignature> =
  <template>
    <svg aria-hidden="true" fill="none" viewBox="0 0 120 80" ...attributes>
      <rect
        fill="var(--secondary)"
        height="48"
        rx="6"
        stroke="var(--primary-low)"
        stroke-width="2"
        width="84"
        x="18"
        y="16"
      />
      <circle cx="34" cy="34" fill="var(--primary-low)" r="9" />
      <rect fill="var(--primary)" height="6" rx="3" width="42" x="50" y="26" />
      <rect
        fill="var(--primary-medium)"
        height="4"
        rx="2"
        width="34"
        x="50"
        y="37"
      />
      <rect
        fill="var(--primary-low-mid)"
        height="4"
        rx="2"
        width="30"
        x="26"
        y="52"
      />
      <rect
        fill="var(--primary-low-mid)"
        height="4"
        rx="2"
        width="20"
        x="66"
        y="52"
      />
    </svg>
  </template>;

export default TopicCardThumbnail;
