/** Palette thumbnail for the `stats` block: a row of number tiles. */
const StatsThumbnail = <template>
  <svg viewBox="0 0 120 80" fill="none" aria-hidden="true" ...attributes>
    <rect x="20" y="26" width="20" height="16" rx="2" fill="var(--primary)" />
    <rect
      x="18"
      y="48"
      width="24"
      height="4"
      rx="2"
      fill="var(--primary-medium)"
    />

    <rect x="50" y="26" width="20" height="16" rx="2" fill="var(--tertiary)" />
    <rect
      x="48"
      y="48"
      width="24"
      height="4"
      rx="2"
      fill="var(--primary-medium)"
    />

    <rect x="80" y="26" width="20" height="16" rx="2" fill="var(--primary)" />
    <rect
      x="78"
      y="48"
      width="24"
      height="4"
      rx="2"
      fill="var(--primary-medium)"
    />
  </svg>
</template>;

export default StatsThumbnail;
