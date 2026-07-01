/** Palette thumbnail for the `media-card` block: a card with a media header and text. */
const MediaCardThumbnail = <template>
  <svg viewBox="0 0 120 80" fill="none" aria-hidden="true" ...attributes>
    <rect
      x="24"
      y="14"
      width="72"
      height="52"
      rx="6"
      fill="var(--secondary)"
      stroke="var(--primary-low)"
      stroke-width="2"
    />
    <rect
      x="24"
      y="14"
      width="72"
      height="24"
      rx="6"
      fill="var(--primary-low)"
    />
    <circle cx="60" cy="26" r="6" fill="var(--tertiary)" />
    <path d="M58 23 L63 26 L58 29 Z" fill="var(--secondary)" />
    <rect
      x="32"
      y="46"
      width="44"
      height="5"
      rx="2"
      fill="var(--primary-low-mid)"
    />
    <rect
      x="32"
      y="55"
      width="32"
      height="4"
      rx="2"
      fill="var(--primary-low-mid)"
    />
  </svg>
</template>;

export default MediaCardThumbnail;
