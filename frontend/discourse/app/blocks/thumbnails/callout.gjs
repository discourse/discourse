/** Palette thumbnail for the `callout` block: an accented note with an icon. */
const CalloutThumbnail = <template>
  <svg viewBox="0 0 120 80" fill="none" aria-hidden="true" ...attributes>
    <rect
      x="16"
      y="20"
      width="88"
      height="40"
      rx="5"
      fill="var(--tertiary-low)"
      stroke="var(--tertiary)"
      stroke-width="1.5"
    />
    <rect x="20" y="24" width="4" height="32" rx="2" fill="var(--tertiary)" />
    <circle cx="34" cy="32" r="4" fill="var(--tertiary)" />
    <rect
      x="44"
      y="30"
      width="50"
      height="4"
      rx="2"
      fill="var(--primary-low-mid)"
    />
    <rect
      x="44"
      y="40"
      width="42"
      height="4"
      rx="2"
      fill="var(--primary-low-mid)"
    />
    <rect
      x="44"
      y="50"
      width="34"
      height="4"
      rx="2"
      fill="var(--primary-low-mid)"
    />
  </svg>
</template>;

export default CalloutThumbnail;
