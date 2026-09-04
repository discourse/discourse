import type { TemplateOnlyComponent } from "@ember/component/template-only";

interface TabsThumbnailSignature {
  Element: SVGSVGElement;
}

/** Palette thumbnail for the `tabs` block: an active tab joined to its panel. */
const TabsThumbnail: TemplateOnlyComponent<TabsThumbnailSignature> = <template>
  <svg viewBox="0 0 120 80" fill="none" aria-hidden="true" ...attributes>
    <rect
      x="47"
      y="18"
      width="26"
      height="14"
      rx="3"
      fill="var(--primary-low)"
    />
    <rect
      x="77"
      y="18"
      width="26"
      height="14"
      rx="3"
      fill="var(--primary-low)"
    />
    <rect
      x="51"
      y="24"
      width="16"
      height="3"
      rx="1.5"
      fill="var(--primary-medium)"
    />
    <rect
      x="81"
      y="24"
      width="16"
      height="3"
      rx="1.5"
      fill="var(--primary-medium)"
    />
    <rect
      x="12"
      y="30"
      width="96"
      height="38"
      rx="5"
      fill="var(--secondary)"
      stroke="var(--primary-low)"
      stroke-width="2"
    />
    <path
      d="M14 34 V20 a3 3 0 0 1 3 -3 H43 a3 3 0 0 1 3 3 V34"
      fill="var(--secondary)"
      stroke="var(--primary-low)"
      stroke-width="2"
    />
    <rect x="15" y="17" width="30" height="3" rx="1.5" fill="var(--tertiary)" />
    <rect x="20" y="24" width="20" height="4" rx="2" fill="var(--primary)" />
    <rect
      x="20"
      y="40"
      width="62"
      height="4"
      rx="2"
      fill="var(--primary-low-mid)"
    />
    <rect
      x="20"
      y="48"
      width="78"
      height="4"
      rx="2"
      fill="var(--primary-low-mid)"
    />
    <rect
      x="20"
      y="56"
      width="46"
      height="4"
      rx="2"
      fill="var(--primary-low-mid)"
    />
  </svg>
</template>;

export default TabsThumbnail;
