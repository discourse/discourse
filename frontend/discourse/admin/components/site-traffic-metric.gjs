import DTooltip from "discourse/float-kit/components/d-tooltip";
import { i18n } from "discourse-i18n";

export default <template>
  <div
    class="site-traffic-explorer__metric"
    data-test-site-traffic-metric={{@name}}
  >
    <div class="site-traffic-explorer__metric-value">{{@value}}</div>
    <div class="site-traffic-explorer__metric-label">
      {{@label}}
      <DTooltip
        @identifier={{@name}}
        @icon="far-circle-question"
        @title={{i18n "admin.site_traffic_explorer.metric_information"}}
      >
        <:content>{{@tooltip}}</:content>
      </DTooltip>
    </div>
  </div>
</template>
