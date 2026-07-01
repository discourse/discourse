/** Palette thumbnail for the `section` block: a container wrapping child blocks. */
const SectionThumbnail = <template>
  <svg viewBox="0 0 120 80" fill="none" aria-hidden="true" ...attributes>
    <rect
      x="10"
      y="12"
      width="100"
      height="56"
      rx="6"
      fill="none"
      stroke="var(--primary-low-mid)"
      stroke-width="2"
      stroke-dasharray="5 4"
    />
    <rect
      x="20"
      y="22"
      width="80"
      height="14"
      rx="3"
      fill="var(--primary-low)"
    />
    <rect
      x="20"
      y="42"
      width="38"
      height="16"
      rx="3"
      fill="var(--primary-low)"
    />
    <rect
      x="62"
      y="42"
      width="38"
      height="16"
      rx="3"
      fill="var(--primary-low)"
    />
  </svg>
</template>;

export default SectionThumbnail;
