import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface CardThumbnailSignature {
  // Root element type (enables ...attributes type checking)
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `card` block: a framed card with media and text. */
const CardThumbnail: TemplateOnlyComponent<CardThumbnailSignature> = <template>
  <svg viewBox="0 0 120 80" fill="none" aria-hidden="true" ...attributes>
    <rect
      x="22"
      y="14"
      width="76"
      height="52"
      rx="6"
      fill="var(--secondary)"
      stroke="var(--primary-low)"
      stroke-width="2"
    />
    <rect
      x="30"
      y="22"
      width="60"
      height="20"
      rx="3"
      fill="var(--primary-low)"
    />
    <rect
      x="30"
      y="48"
      width="44"
      height="5"
      rx="2"
      fill="var(--primary-low-mid)"
    />
    <rect
      x="30"
      y="57"
      width="32"
      height="5"
      rx="2"
      fill="var(--primary-low-mid)"
    />
  </svg>
</template>;

export default CardThumbnail;
