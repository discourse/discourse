import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface NewTopicButtonThumbnailSignature {
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `new-topic-button` block: a button with a plus. */
const NewTopicButtonThumbnail: TemplateOnlyComponent<NewTopicButtonThumbnailSignature> =
  <template>
    <svg aria-hidden="true" fill="none" viewBox="0 0 120 80" ...attributes>
      <rect
        fill="var(--tertiary)"
        height="20"
        rx="6"
        width="64"
        x="28"
        y="30"
      />
      <rect
        fill="var(--secondary)"
        height="2.5"
        rx="1.25"
        width="9"
        x="38"
        y="38.75"
      />
      <rect
        fill="var(--secondary)"
        height="9"
        rx="1.25"
        width="2.5"
        x="41.25"
        y="35.5"
      />
      <rect
        fill="var(--secondary)"
        height="4"
        rx="2"
        width="30"
        x="52"
        y="38"
      />
    </svg>
  </template>;

export default NewTopicButtonThumbnail;
