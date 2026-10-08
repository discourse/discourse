import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface TabsThumbnailSignature {
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `tabs` block: an active tab joined to its panel. */
const TabsThumbnail: TemplateOnlyComponent<TabsThumbnailSignature> = <template>
  <svg aria-hidden="true" fill="none" viewBox="0 0 120 80" ...attributes>
    <rect
      fill="var(--primary-low)"
      height="14"
      rx="3"
      width="26"
      x="47"
      y="18"
    />
    <rect
      fill="var(--primary-low)"
      height="14"
      rx="3"
      width="26"
      x="77"
      y="18"
    />
    <rect
      fill="var(--primary-medium)"
      height="3"
      rx="1.5"
      width="16"
      x="51"
      y="24"
    />
    <rect
      fill="var(--primary-medium)"
      height="3"
      rx="1.5"
      width="16"
      x="81"
      y="24"
    />
    <rect
      fill="var(--secondary)"
      height="38"
      rx="5"
      stroke="var(--primary-low)"
      stroke-width="2"
      width="96"
      x="12"
      y="30"
    />
    <path
      d="M14 34 V20 a3 3 0 0 1 3 -3 H43 a3 3 0 0 1 3 3 V34"
      fill="var(--secondary)"
      stroke="var(--primary-low)"
      stroke-width="2"
    />
    <rect fill="var(--tertiary)" height="3" rx="1.5" width="30" x="15" y="17" />
    <rect fill="var(--primary)" height="4" rx="2" width="20" x="20" y="24" />
    <rect
      fill="var(--primary-low-mid)"
      height="4"
      rx="2"
      width="62"
      x="20"
      y="40"
    />
    <rect
      fill="var(--primary-low-mid)"
      height="4"
      rx="2"
      width="78"
      x="20"
      y="48"
    />
    <rect
      fill="var(--primary-low-mid)"
      height="4"
      rx="2"
      width="46"
      x="20"
      y="56"
    />
  </svg>
</template>;

export default TabsThumbnail;
