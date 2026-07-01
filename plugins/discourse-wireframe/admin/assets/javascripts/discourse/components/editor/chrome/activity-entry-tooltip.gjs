// @ts-check
import { i18n } from "discourse-i18n";

/**
 * Hover card for an activity-bar entry: the panel's name plus a one-line hint.
 * The icon-only rail relies on this for discoverability (the button itself
 * carries only an `aria-label`). FloatKit injects the entry — `{label,
 * description}` i18n keys — as `@data.entry` via `tooltip.register`.
 */
const ActivityEntryTooltip = <template>
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
