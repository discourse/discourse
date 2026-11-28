import DPill from "discourse/ui-kit/d-pill";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="styleguide-pill-row">
    <DPill
      @icon="circle"
      @label={{i18n "styleguide.sections.pill.live"}}
      @type="success"
    />
    <DPill @icon="lock" @label={{i18n "styleguide.sections.pill.locked"}} />
    <DPill
      @icon="far-clock"
      @label={{i18n "styleguide.sections.pill.scheduled"}}
      @type="info"
    />
  </div>
</template>
