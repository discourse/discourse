import DPill from "discourse/ui-kit/d-pill";
import { i18n } from "discourse-i18n";

export default <template>
  <ul class="styleguide-pill-context">
    <li>
      {{i18n "styleguide.sections.pill.timezone_place"}}
      <DPill @label={{i18n "styleguide.sections.pill.neutral"}} />
      {{i18n "styleguide.sections.pill.timezone_time"}}
    </li>
    <li>
      {{i18n "styleguide.sections.pill.category_name"}}
      <DPill @label={{i18n "styleguide.sections.pill.locked"}} />
    </li>
    <li>
      {{i18n "styleguide.sections.pill.event_title"}}
      <DPill @label={{i18n "styleguide.sections.pill.info"}} @type="info" />
    </li>
    <li>
      {{i18n "styleguide.sections.pill.device_name"}}
      <DPill @label={{i18n "styleguide.sections.pill.danger"}} />
    </li>
  </ul>
</template>
