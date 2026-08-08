import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface VideoThumbnailSignature {
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `video` block: a player with a play button and scrubber. */
const VideoThumbnail: TemplateOnlyComponent<VideoThumbnailSignature> =
  <template>
    <svg viewBox="0 0 120 80" fill="none" aria-hidden="true" ...attributes>
      <rect
        x="18"
        y="16"
        width="84"
        height="44"
        rx="6"
        fill="var(--primary-low)"
        stroke="var(--primary-low-mid)"
        stroke-width="1.5"
      />
      <circle cx="60" cy="35" r="11" fill="var(--tertiary)" />
      <path d="M56 30 L66 35 L56 40 Z" fill="var(--secondary)" />
      <rect
        x="26"
        y="51"
        width="68"
        height="3"
        rx="1.5"
        fill="var(--primary-low-mid)"
      />
      <rect
        x="26"
        y="51"
        width="26"
        height="3"
        rx="1.5"
        fill="var(--tertiary)"
      />
    </svg>
  </template>;

export default VideoThumbnail;
