import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface TagBannerThumbnailSignature {
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `tag-banner` block: a banner with a tag pill and title. */
const TagBannerThumbnail: TemplateOnlyComponent<TagBannerThumbnailSignature> =
  <template>
    <svg aria-hidden="true" fill="none" viewBox="0 0 120 80" ...attributes>
      <rect
        fill="var(--primary-low)"
        height="44"
        rx="6"
        width="96"
        x="12"
        y="18"
      />
      <rect
        fill="var(--tertiary-low)"
        height="12"
        rx="6"
        width="26"
        x="24"
        y="26"
      />
      <rect fill="var(--tertiary)" height="4" rx="2" width="16" x="29" y="30" />
      <rect fill="var(--primary)" height="7" rx="3" width="52" x="24" y="44" />
    </svg>
  </template>;

export default TagBannerThumbnail;
