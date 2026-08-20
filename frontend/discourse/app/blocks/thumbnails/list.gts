import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface ListThumbnailSignature {
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `list` block: a bulleted list. */
const ListThumbnail: TemplateOnlyComponent<ListThumbnailSignature> = <template>
  <svg viewBox="0 0 120 80" fill="none" aria-hidden="true" ...attributes>
    <circle cx="22" cy="22" r="2.5" fill="var(--primary-medium)" />
    <rect
      x="32"
      y="20"
      width="72"
      height="5"
      rx="2"
      fill="var(--primary-low-mid)"
    />

    <circle cx="22" cy="34" r="2.5" fill="var(--primary-medium)" />
    <rect
      x="32"
      y="32"
      width="62"
      height="5"
      rx="2"
      fill="var(--primary-low-mid)"
    />

    <circle cx="22" cy="46" r="2.5" fill="var(--primary-medium)" />
    <rect
      x="32"
      y="44"
      width="70"
      height="5"
      rx="2"
      fill="var(--primary-low-mid)"
    />

    <circle cx="22" cy="58" r="2.5" fill="var(--primary-medium)" />
    <rect
      x="32"
      y="56"
      width="54"
      height="5"
      rx="2"
      fill="var(--primary-low-mid)"
    />
  </svg>
</template>;

export default ListThumbnail;
