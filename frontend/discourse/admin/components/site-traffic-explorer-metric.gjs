import { concat } from "@ember/helper";
import SiteTrafficExplorerPageviewCount from "discourse/admin/components/site-traffic-explorer-pageview-count";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import { i18n } from "discourse-i18n";

export default <template>
  <div
    class="site-traffic-explorer__metric {{if @primary '--primary'}}"
    data-test-site-traffic-metric={{@name}}
  >
    {{#if @compact}}
      <SiteTrafficExplorerPageviewCount @value={{@value}} as |formattedValue|>
        <span
          class="db-section__metric-number site-traffic-explorer__metric-value"
        >{{formattedValue}}</span>
      </SiteTrafficExplorerPageviewCount>
    {{else}}
      <span
        class="db-section__metric-number site-traffic-explorer__metric-value"
      >{{@value}}</span>
    {{/if}}
    <span class="site-traffic-explorer__metric-label-row">
      <span
        class="db-section__metric-label site-traffic-explorer__metric-label"
      >{{@label}}</span>
      {{#if @tooltip}}
        <DTooltip
          class="db-section__info"
          @identifier={{concat "site-traffic-explorer-" @name "-tooltip"}}
          @icon="far-circle-question"
          @title={{i18n "admin.site_traffic_explorer.metric_information"}}
        >
          <:content>{{@tooltip}}</:content>
        </DTooltip>
      {{/if}}
    </span>
  </div>
</template>
