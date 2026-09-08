import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface ListThumbnailSignature {
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `list` block: a bulleted list. */
const ListThumbnail: TemplateOnlyComponent<ListThumbnailSignature> = <template>
  <svg aria-hidden="true" fill="none" viewBox="0 0 120 80" ...attributes>
    <circle cx="22" cy="22" fill="var(--primary-medium)" r="2.5" />
    <rect
      fill="var(--primary-low-mid)"
      height="5"
      rx="2"
      width="72"
      x="32"
      y="20"
    />

    <circle cx="22" cy="34" fill="var(--primary-medium)" r="2.5" />
    <rect
      fill="var(--primary-low-mid)"
      height="5"
      rx="2"
      width="62"
      x="32"
      y="32"
    />

    <circle cx="22" cy="46" fill="var(--primary-medium)" r="2.5" />
    <rect
      fill="var(--primary-low-mid)"
      height="5"
      rx="2"
      width="70"
      x="32"
      y="44"
    />

    <circle cx="22" cy="58" fill="var(--primary-medium)" r="2.5" />
    <rect
      fill="var(--primary-low-mid)"
      height="5"
      rx="2"
      width="54"
      x="32"
      y="56"
    />
  </svg>
</template>;

export default ListThumbnail;
