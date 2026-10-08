import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface CalloutThumbnailSignature {
  // Root element type (enables ...attributes type checking)
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `callout` block: an accented note with an icon. */
const CalloutThumbnail: TemplateOnlyComponent<CalloutThumbnailSignature> =
  <template>
    <svg aria-hidden="true" fill="none" viewBox="0 0 120 80" ...attributes>
      <rect
        fill="var(--tertiary-low)"
        height="40"
        rx="5"
        stroke="var(--tertiary)"
        stroke-width="1.5"
        width="88"
        x="16"
        y="20"
      />
      <rect fill="var(--tertiary)" height="32" rx="2" width="4" x="20" y="24" />
      <circle cx="34" cy="32" fill="var(--tertiary)" r="4" />
      <rect
        fill="var(--primary-low-mid)"
        height="4"
        rx="2"
        width="50"
        x="44"
        y="30"
      />
      <rect
        fill="var(--primary-low-mid)"
        height="4"
        rx="2"
        width="42"
        x="44"
        y="40"
      />
      <rect
        fill="var(--primary-low-mid)"
        height="4"
        rx="2"
        width="34"
        x="44"
        y="50"
      />
    </svg>
  </template>;

export default CalloutThumbnail;
