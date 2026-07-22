import type { TemplateOnlyComponent } from "@ember/component/template-only";
import { i18n } from "discourse-i18n";

export interface ActivityEntry {
  /** The i18n key for the panel's name. */
  label: string;

  /** The i18n key for the panel's one-line hint. */
  description: string;
}

interface ActivityEntryTooltipSignature {
  /** FloatKit tooltip payload. */
  Args: {
    /**
     * The activity-bar entry FloatKit injects via `tooltip.register`, holding
     * the i18n keys the card renders.
     */
    data: {
      /** Activity entry described by the tooltip. */
      entry: ActivityEntry;
    };
  };
  /** Root tooltip element. */
  Element: HTMLDivElement;
}

/**
 * Hover card for an activity-bar entry: the panel's name plus a one-line hint.
 * The icon-only rail relies on this for discoverability (the button itself
 * carries only an `aria-label`). FloatKit injects the entry — `{label,
 * description}` i18n keys — as `@data.entry` via `tooltip.register`.
 */
const ActivityEntryTooltip: TemplateOnlyComponent<ActivityEntryTooltipSignature> =
  <template>
    <div class="wireframe-activity-tooltip">
      <span class="wireframe-activity-tooltip__name">
        {{i18n @data.entry.label}}
      </span>
      <span class="wireframe-activity-tooltip__description">
        {{i18n @data.entry.description}}
      </span>
    </div>
  </template>;

export default ActivityEntryTooltip;
