import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface CardThumbnailSignature {
  // Root element type (enables ...attributes type checking)
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `card` block: a framed card with media and text. */
const CardThumbnail: TemplateOnlyComponent<CardThumbnailSignature> = <template>
  <svg aria-hidden="true" fill="none" viewBox="0 0 120 80" ...attributes>
    <rect
      fill="var(--secondary)"
      height="52"
      rx="6"
      stroke="var(--primary-low)"
      stroke-width="2"
      width="76"
      x="22"
      y="14"
    />
    <rect
      fill="var(--primary-low)"
      height="20"
      rx="3"
      width="60"
      x="30"
      y="22"
    />
    <rect
      fill="var(--primary-low-mid)"
      height="5"
      rx="2"
      width="44"
      x="30"
      y="48"
    />
    <rect
      fill="var(--primary-low-mid)"
      height="5"
      rx="2"
      width="32"
      x="30"
      y="57"
    />
  </svg>
</template>;

export default CardThumbnail;
