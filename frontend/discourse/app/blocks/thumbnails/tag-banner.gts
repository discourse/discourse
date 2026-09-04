import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface TagBannerThumbnailSignature {
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `tag-banner` block: a banner with a tag pill and title. */
const TagBannerThumbnail: TemplateOnlyComponent<TagBannerThumbnailSignature> =
  <template>
    <svg viewBox="0 0 120 80" fill="none" aria-hidden="true" ...attributes>
      <rect
        x="12"
        y="18"
        width="96"
        height="44"
        rx="6"
        fill="var(--primary-low)"
      />
      <rect
        x="24"
        y="26"
        width="26"
        height="12"
        rx="6"
        fill="var(--tertiary-low)"
      />
      <rect x="29" y="30" width="16" height="4" rx="2" fill="var(--tertiary)" />
      <rect x="24" y="44" width="52" height="7" rx="3" fill="var(--primary)" />
    </svg>
  </template>;

export default TagBannerThumbnail;
