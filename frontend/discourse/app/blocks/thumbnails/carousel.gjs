/** Palette thumbnail for the `carousel` block: a center slide with peeking neighbors. */
const CarouselThumbnail = <template>
  <svg viewBox="0 0 120 80" fill="none" aria-hidden="true" ...attributes>
    <rect
      x="8"
      y="24"
      width="15"
      height="32"
      rx="3"
      fill="var(--primary-low)"
    />
    <rect
      x="97"
      y="24"
      width="15"
      height="32"
      rx="3"
      fill="var(--primary-low)"
    />
    <rect
      x="30"
      y="13"
      width="60"
      height="47"
      rx="5"
      fill="var(--secondary)"
      stroke="var(--primary-low)"
      stroke-width="2"
    />
    <rect
      x="36"
      y="19"
      width="48"
      height="20"
      rx="3"
      fill="var(--tertiary-low)"
    />
    <circle cx="60" cy="29" r="6" fill="var(--tertiary)" />
    <path d="M58 26 L64 29 L58 32 Z" fill="var(--secondary)" />
    <rect
      x="36"
      y="45"
      width="40"
      height="4"
      rx="2"
      fill="var(--primary-low-mid)"
    />
    <rect
      x="36"
      y="52"
      width="27"
      height="4"
      rx="2"
      fill="var(--primary-low-mid)"
    />
    <circle cx="52" cy="71" r="2.5" fill="var(--primary-low-mid)" />
    <circle cx="60" cy="71" r="2.5" fill="var(--tertiary)" />
    <circle cx="68" cy="71" r="2.5" fill="var(--primary-low-mid)" />
  </svg>
</template>;

export default CarouselThumbnail;
