/** Palette thumbnail for the `chat:featured-channels` block: a cluster of chat speech bubbles. */
const FeaturedChatChannelsThumbnail = <template>
  <svg aria-hidden="true" fill="none" viewBox="0 0 120 80" ...attributes>
    {{! Top-left bubble (tail bottom-left) }}
    <path
      d="M 14,10 H 46 Q 52,10 52,16 V 26 Q 52,32 46,32 H 26 L 16,40 L 20,32 H 14 Q 8,32 8,26 V 16 Q 8,10 14,10 Z"
      fill="var(--primary-very-low)"
      stroke="var(--primary-low)"
    />
    <circle cx="18" cy="21" fill="var(--tertiary)" r="3" />
    <rect
      fill="var(--primary-low-mid)"
      height="5"
      rx="2"
      width="20"
      x="26"
      y="18"
    />

    {{! Top-right bubble (tail bottom-right) }}
    <path
      d="M 74,10 H 104 Q 110,10 110,16 V 26 Q 110,32 104,32 L 108,42 L 100,32 H 74 Q 68,32 68,26 V 16 Q 68,10 74,10 Z"
      fill="var(--primary-very-low)"
      stroke="var(--primary-low)"
    />
    <circle cx="78" cy="21" fill="var(--success)" r="3" />
    <rect
      fill="var(--primary-low-mid)"
      height="5"
      rx="2"
      width="18"
      x="86"
      y="18"
    />

    {{! Bottom-center bubble (tail bottom-left) }}
    <path
      d="M 44,42 H 76 Q 82,42 82,48 V 58 Q 82,64 76,64 H 56 L 46,72 L 50,64 H 44 Q 38,64 38,58 V 48 Q 38,42 44,42 Z"
      fill="var(--primary-very-low)"
      stroke="var(--primary-low)"
    />
    <circle cx="48" cy="53" fill="var(--love)" r="3" />
    <rect
      fill="var(--primary-low-mid)"
      height="5"
      rx="2"
      width="20"
      x="56"
      y="50"
    />
  </svg>
</template>;

export default FeaturedChatChannelsThumbnail;
