import { concat } from "@ember/helper";
import SiteTrafficExplorerPageviewCount from "discourse/admin/components/site-traffic-explorer-pageview-count";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="db-section__metric" data-test-site-traffic-metric={{@name}}>
    {{#if @compact}}
      <SiteTrafficExplorerPageviewCount @value={{@value}} as |formattedValue|>
        <div class="db-section__metric-number">{{formattedValue}}</div>
      </SiteTrafficExplorerPageviewCount>
    {{else}}
      <div class="db-section__metric-number">{{@value}}</div>
    {{/if}}

    <div class="db-section__metric-label">{{@label}}
      {{#if @tooltip}}
        <DTooltip
          class="db-section__info"
          @identifier={{concat "site-traffic-explorer-" @name "-tooltip"}}
          @icon="far-circle-question"
          @title={{i18n "admin.site_traffic_explorer.metric_information"}}
        >
          <:content>{{@tooltip}}</:content>
        </DTooltip>
      {{/if}}</div>

  </div>
</template>
