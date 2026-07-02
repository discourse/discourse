/** Palette thumbnail for the `heading` block: a bold title bar over two lines. */
const HeadingThumbnail = <template>
  <svg viewBox="0 0 120 80" fill="none" aria-hidden="true" ...attributes>
    <rect x="16" y="22" width="64" height="12" rx="2" fill="var(--primary)" />
    <rect
      x="16"
      y="44"
      width="88"
      height="5"
      rx="2"
      fill="var(--primary-low-mid)"
    />
    <rect
      x="16"
      y="54"
      width="72"
      height="5"
      rx="2"
      fill="var(--primary-low-mid)"
    />
  </svg>
</template>;

export default HeadingThumbnail;
