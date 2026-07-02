/** Palette thumbnail for the `topic-card` block: a card with avatar, title and meta. */
const TopicCardThumbnail = <template>
  <svg viewBox="0 0 120 80" fill="none" aria-hidden="true" ...attributes>
    <rect
      x="18"
      y="16"
      width="84"
      height="48"
      rx="6"
      fill="var(--secondary)"
      stroke="var(--primary-low)"
      stroke-width="2"
    />
    <circle cx="34" cy="34" r="9" fill="var(--primary-low)" />
    <rect x="50" y="26" width="42" height="6" rx="3" fill="var(--primary)" />
    <rect
      x="50"
      y="37"
      width="34"
      height="4"
      rx="2"
      fill="var(--primary-medium)"
    />
    <rect
      x="26"
      y="52"
      width="30"
      height="4"
      rx="2"
      fill="var(--primary-low-mid)"
    />
    <rect
      x="66"
      y="52"
      width="20"
      height="4"
      rx="2"
      fill="var(--primary-low-mid)"
    />
  </svg>
</template>;

export default TopicCardThumbnail;
