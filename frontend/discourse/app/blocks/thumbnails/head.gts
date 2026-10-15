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
  <svg aria-hidden="true" fill="none" viewBox="0 0 120 80" ...attributes>
    <rect
      fill="var(--secondary)"
      height="20"
      rx="4"
      stroke="var(--tertiary)"
      stroke-width="2"
      width="88"
      x="16"
      y="13"
    />
    <path
      d="M26 23 L30 27 L37 19"
      stroke="var(--tertiary)"
      stroke-linecap="round"
      stroke-linejoin="round"
      stroke-width="2.5"
    />
    <rect
      fill="var(--primary-medium)"
      height="5"
      rx="2"
      width="46"
      x="48"
      y="21"
    />

    <rect
      height="15"
      rx="4"
      stroke="var(--primary-low-mid)"
      stroke-dasharray="4 4"
      stroke-width="1.5"
      width="88"
      x="16"
      y="40"
    />
    <rect
      fill="var(--primary-low)"
      height="4"
      rx="2"
      width="52"
      x="26"
      y="45"
    />

    <rect
      height="15"
      rx="4"
      stroke="var(--primary-low-mid)"
      stroke-dasharray="4 4"
      stroke-width="1.5"
      width="88"
      x="16"
      y="61"
    />
    <rect
      fill="var(--primary-low)"
      height="4"
      rx="2"
      width="40"
      x="26"
      y="66"
    />
  </svg>
</template>;

export default HeadThumbnail;
