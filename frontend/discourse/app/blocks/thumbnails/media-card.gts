import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface MediaCardThumbnailSignature {
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `media-card` block: a card with a media header and text. */
const MediaCardThumbnail: TemplateOnlyComponent<MediaCardThumbnailSignature> =
  <template>
    <svg aria-hidden="true" fill="none" viewBox="0 0 120 80" ...attributes>
      <rect
        fill="var(--secondary)"
        height="52"
        rx="6"
        stroke="var(--primary-low)"
        stroke-width="2"
        width="72"
        x="24"
        y="14"
      />
      <rect
        fill="var(--primary-low)"
        height="24"
        rx="6"
        width="72"
        x="24"
        y="14"
      />
      <circle cx="60" cy="26" fill="var(--tertiary)" r="6" />
      <path d="M58 23 L63 26 L58 29 Z" fill="var(--secondary)" />
      <rect
        fill="var(--primary-low-mid)"
        height="5"
        rx="2"
        width="44"
        x="32"
        y="46"
      />
      <rect
        fill="var(--primary-low-mid)"
        height="4"
        rx="2"
        width="32"
        x="32"
        y="55"
      />
    </svg>
  </template>;

export default MediaCardThumbnail;
