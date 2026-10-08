import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface LinkListThumbnailSignature {
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `link-list` block: a vertical list of links. */
const LinkListThumbnail: TemplateOnlyComponent<LinkListThumbnailSignature> =
  <template>
    <svg aria-hidden="true" fill="none" viewBox="0 0 120 80" ...attributes>
      <rect fill="var(--tertiary)" height="5" rx="2" width="70" x="18" y="20" />
      <path
        d="M96 19 L100 23 L96 27"
        stroke="var(--primary-low-mid)"
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
      />

      <rect fill="var(--tertiary)" height="5" rx="2" width="58" x="18" y="38" />
      <path
        d="M96 37 L100 41 L96 45"
        stroke="var(--primary-low-mid)"
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
      />

      <rect fill="var(--tertiary)" height="5" rx="2" width="66" x="18" y="56" />
      <path
        d="M96 55 L100 59 L96 63"
        stroke="var(--primary-low-mid)"
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
      />
    </svg>
  </template>;

export default LinkListThumbnail;
