import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface CarouselThumbnailSignature {
  // Root element type (enables ...attributes type checking)
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `carousel` block: a center slide with peeking neighbors. */
const CarouselThumbnail: TemplateOnlyComponent<CarouselThumbnailSignature> =
  <template>
    <svg aria-hidden="true" fill="none" viewBox="0 0 120 80" ...attributes>
      <rect
        fill="var(--primary-low)"
        height="32"
        rx="3"
        width="15"
        x="8"
        y="24"
      />
      <rect
        fill="var(--primary-low)"
        height="32"
        rx="3"
        width="15"
        x="97"
        y="24"
      />
      <rect
        fill="var(--secondary)"
        height="47"
        rx="5"
        stroke="var(--primary-low)"
        stroke-width="2"
        width="60"
        x="30"
        y="13"
      />
      <rect
        fill="var(--tertiary-low)"
        height="20"
        rx="3"
        width="48"
        x="36"
        y="19"
      />
      <circle cx="60" cy="29" fill="var(--tertiary)" r="6" />
      <path d="M58 26 L64 29 L58 32 Z" fill="var(--secondary)" />
      <rect
        fill="var(--primary-low-mid)"
        height="4"
        rx="2"
        width="40"
        x="36"
        y="45"
      />
      <rect
        fill="var(--primary-low-mid)"
        height="4"
        rx="2"
        width="27"
        x="36"
        y="52"
      />
      <circle cx="52" cy="71" fill="var(--primary-low-mid)" r="2.5" />
      <circle cx="60" cy="71" fill="var(--tertiary)" r="2.5" />
      <circle cx="68" cy="71" fill="var(--primary-low-mid)" r="2.5" />
    </svg>
  </template>;

export default CarouselThumbnail;
