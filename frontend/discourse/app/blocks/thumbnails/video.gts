import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface VideoThumbnailSignature {
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `video` block: a player with a play button and scrubber. */
const VideoThumbnail: TemplateOnlyComponent<VideoThumbnailSignature> =
  <template>
    <svg aria-hidden="true" fill="none" viewBox="0 0 120 80" ...attributes>
      <rect
        fill="var(--primary-low)"
        height="44"
        rx="6"
        stroke="var(--primary-low-mid)"
        stroke-width="1.5"
        width="84"
        x="18"
        y="16"
      />
      <circle cx="60" cy="35" fill="var(--tertiary)" r="11" />
      <path d="M56 30 L66 35 L56 40 Z" fill="var(--secondary)" />
      <rect
        fill="var(--primary-low-mid)"
        height="3"
        rx="1.5"
        width="68"
        x="26"
        y="51"
      />
      <rect
        fill="var(--tertiary)"
        height="3"
        rx="1.5"
        width="26"
        x="26"
        y="51"
      />
    </svg>
  </template>;

export default VideoThumbnail;
