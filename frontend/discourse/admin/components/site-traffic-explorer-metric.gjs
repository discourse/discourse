import { concat } from "@ember/helper";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="db-section__metric" data-test-site-traffic-metric={{@name}}>
    <div class="db-section__metric-number">{{@value}}</div>

    <div class="db-section__metric-label">{{@label}}
      {{#if @tooltip}}
        <DTooltip
          class="db-section__info"
          @identifier={{concat "site-traffic-explorer-" @name "-tooltip"}}
          @icon="far-circle-question"
          aria-label={{i18n
            "admin.site_traffic_explorer.metric_information"
            metric=@label
          }}
        >
          <:content>{{@tooltip}}</:content>
        </DTooltip>
      {{/if}}</div>

  </div>
</template>
