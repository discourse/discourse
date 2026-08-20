import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface HeadThumbnailSignature {
  // Root element type (enables ...attributes type checking)
  Element: SVGSVGElement;
}

/**
 * Palette thumbnail for the `head` block: a set of candidate children with only
 * the first passing one selected (checked) and the rest skipped (dashed) —
 * conveying "render the first child whose conditions pass".
 */
const HeadThumbnail: TemplateOnlyComponent<HeadThumbnailSignature> = <template>
  <svg viewBox="0 0 120 80" fill="none" aria-hidden="true" ...attributes>
    <rect
      x="16"
      y="13"
      width="88"
      height="20"
      rx="4"
      fill="var(--secondary)"
      stroke="var(--tertiary)"
      stroke-width="2"
    />
    <path
      d="M26 23 L30 27 L37 19"
      stroke="var(--tertiary)"
      stroke-width="2.5"
      stroke-linecap="round"
      stroke-linejoin="round"
    />
    <rect
      x="48"
      y="21"
      width="46"
      height="5"
      rx="2"
      fill="var(--primary-medium)"
    />

    <rect
      x="16"
      y="40"
      width="88"
      height="15"
      rx="4"
      stroke="var(--primary-low-mid)"
      stroke-width="1.5"
      stroke-dasharray="4 4"
    />
    <rect
      x="26"
      y="45"
      width="52"
      height="4"
      rx="2"
      fill="var(--primary-low)"
    />

    <rect
      x="16"
      y="61"
      width="88"
      height="15"
      rx="4"
      stroke="var(--primary-low-mid)"
      stroke-width="1.5"
      stroke-dasharray="4 4"
    />
    <rect
      x="26"
      y="66"
      width="40"
      height="4"
      rx="2"
      fill="var(--primary-low)"
    />
  </svg>
</template>;

export default HeadThumbnail;
