/** Palette thumbnail for the `chat:channel-card` block: a single chat speech bubble. */
const ChatChannelCardThumbnail = <template>
  <svg viewBox="0 0 120 80" fill="none" aria-hidden="true" ...attributes>
    {{! Speech bubble with a tail at the bottom-left }}
    <path
      d="M 28,14 H 92 Q 100,14 100,22 V 48 Q 100,56 92,56 H 42 L 34,68 L 30,56 H 28 Q 20,56 20,48 V 22 Q 20,14 28,14 Z"
      fill="var(--primary-very-low)"
      stroke="var(--primary-low)"
    />
    <circle cx="36" cy="28" r="5" fill="var(--tertiary)" />
    <rect
      x="48"
      y="25"
      width="38"
      height="6"
      rx="3"
      fill="var(--primary-medium)"
    />
    <rect
      x="30"
      y="41"
      width="54"
      height="4"
      rx="2"
      fill="var(--primary-low-mid)"
    />
    <rect
      x="30"
      y="48"
      width="36"
      height="4"
      rx="2"
      fill="var(--primary-low-mid)"
    />
  </svg>
</template>;

export default ChatChannelCardThumbnail;
