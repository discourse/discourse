import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface RecentTopicsThumbnailSignature {
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `recent-topics` block: a list of topic rows. */
const RecentTopicsThumbnail: TemplateOnlyComponent<RecentTopicsThumbnailSignature> =
  <template>
    <svg aria-hidden="true" fill="none" viewBox="0 0 120 80" ...attributes>
      <circle cx="24" cy="24" fill="var(--primary-low-mid)" r="6" />
      <rect
        fill="var(--primary-low-mid)"
        height="5"
        rx="2"
        width="60"
        x="38"
        y="20"
      />
      <rect
        fill="var(--primary-low)"
        height="4"
        rx="2"
        width="34"
        x="38"
        y="28"
      />

      <circle cx="24" cy="44" fill="var(--primary-low-mid)" r="6" />
      <rect
        fill="var(--primary-low-mid)"
        height="5"
        rx="2"
        width="54"
        x="38"
        y="40"
      />
      <rect
        fill="var(--primary-low)"
        height="4"
        rx="2"
        width="30"
        x="38"
        y="48"
      />

      <circle cx="24" cy="64" fill="var(--primary-low-mid)" r="6" />
      <rect
        fill="var(--primary-low-mid)"
        height="5"
        rx="2"
        width="64"
        x="38"
        y="60"
      />
      <rect
        fill="var(--primary-low)"
        height="4"
        rx="2"
        width="26"
        x="38"
        y="68"
      />
    </svg>
  </template>;

export default RecentTopicsThumbnail;
