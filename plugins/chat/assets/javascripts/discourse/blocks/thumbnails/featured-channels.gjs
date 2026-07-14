/** Palette thumbnail for the `chat:featured-channels` block: a cluster of chat speech bubbles. */
const FeaturedChatChannelsThumbnail = <template>
  <svg viewBox="0 0 120 80" fill="none" aria-hidden="true" ...attributes>
    {{! Top-left bubble (tail bottom-left) }}
    <path
      d="M 14,10 H 46 Q 52,10 52,16 V 26 Q 52,32 46,32 H 26 L 16,40 L 20,32 H 14 Q 8,32 8,26 V 16 Q 8,10 14,10 Z"
      fill="var(--primary-very-low)"
      stroke="var(--primary-low)"
    />
    <circle cx="18" cy="21" r="3" fill="var(--tertiary)" />
    <rect
      x="26"
      y="18"
      width="20"
      height="5"
      rx="2"
      fill="var(--primary-low-mid)"
    />

    {{! Top-right bubble (tail bottom-right) }}
    <path
      d="M 74,10 H 104 Q 110,10 110,16 V 26 Q 110,32 104,32 L 108,42 L 100,32 H 74 Q 68,32 68,26 V 16 Q 68,10 74,10 Z"
      fill="var(--primary-very-low)"
      stroke="var(--primary-low)"
    />
    <circle cx="78" cy="21" r="3" fill="var(--success)" />
    <rect
      x="86"
      y="18"
      width="18"
      height="5"
      rx="2"
      fill="var(--primary-low-mid)"
    />

    {{! Bottom-center bubble (tail bottom-left) }}
    <path
      d="M 44,42 H 76 Q 82,42 82,48 V 58 Q 82,64 76,64 H 56 L 46,72 L 50,64 H 44 Q 38,64 38,58 V 48 Q 38,42 44,42 Z"
      fill="var(--primary-very-low)"
      stroke="var(--primary-low)"
    />
    <circle cx="48" cy="53" r="3" fill="var(--love)" />
    <rect
      x="56"
      y="50"
      width="20"
      height="5"
      rx="2"
      fill="var(--primary-low-mid)"
    />
  </svg>
</template>;

export default FeaturedChatChannelsThumbnail;
