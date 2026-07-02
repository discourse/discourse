/** Palette thumbnail for the `link-list` block: a vertical list of links. */
const LinkListThumbnail = <template>
  <svg viewBox="0 0 120 80" fill="none" aria-hidden="true" ...attributes>
    <rect x="18" y="20" width="70" height="5" rx="2" fill="var(--tertiary)" />
    <path
      d="M96 19 L100 23 L96 27"
      stroke="var(--primary-low-mid)"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
    />

    <rect x="18" y="38" width="58" height="5" rx="2" fill="var(--tertiary)" />
    <path
      d="M96 37 L100 41 L96 45"
      stroke="var(--primary-low-mid)"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
    />

    <rect x="18" y="56" width="66" height="5" rx="2" fill="var(--tertiary)" />
    <path
      d="M96 55 L100 59 L96 63"
      stroke="var(--primary-low-mid)"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
    />
  </svg>
</template>;

export default LinkListThumbnail;
