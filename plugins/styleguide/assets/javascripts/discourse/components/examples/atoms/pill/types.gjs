import DPill from "discourse/ui-kit/d-pill";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="styleguide-pill-row">
    <DPill @label={{i18n "styleguide.sections.pill.neutral"}} />
    <DPill @label={{i18n "styleguide.sections.pill.info"}} @type="info" />
    <DPill @label={{i18n "styleguide.sections.pill.success"}} @type="success" />
    <DPill @label={{i18n "styleguide.sections.pill.warning"}} @type="warning" />
    <DPill @label={{i18n "styleguide.sections.pill.danger"}} @type="danger" />
  </div>
</template>
