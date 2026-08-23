import { on } from "@ember/modifier";
import SiteTrafficExplorerDimensionLabel from "discourse/admin/components/site-traffic-explorer-dimension-label";
import SiteTrafficExplorerPageviewCount from "discourse/admin/components/site-traffic-explorer-pageview-count";
import { i18n } from "discourse-i18n";

function filterLabel(row) {
  return i18n("admin.site_traffic_explorer.filter_by", {
    label: row.label,
    count: row.pageviews,
  });
}

export default <template>
  <label class="site-traffic-explorer__row" data-test-site-traffic-row>
    <input
      id={{@inputId}}
      class="site-traffic-explorer__row-checkbox"
      type="checkbox"
      aria-label={{filterLabel @row}}
      checked={{@checked}}
      {{on "change" @onToggle}}
    />

    {{#if @rowLink}}
      {{! eslint-disable-next-line ember/template-no-nested-interactive }}
      <a
        href={{@rowLink.href}}
        rel={{@rowLink.rel}}
        target={{@rowLink.target}}
        class="site-traffic-explorer__row-link"
      >
        <SiteTrafficExplorerDimensionLabel
          @dimension={{@dimension}}
          @row={{@row}}
        />
      </a>
    {{else}}
      <SiteTrafficExplorerDimensionLabel
        @dimension={{@dimension}}
        @row={{@row}}
      />
    {{/if}}

    <SiteTrafficExplorerPageviewCount
      @value={{@row.pageviews}}
      as |formattedValue|
    >
      <span class="site-traffic-explorer__row-count">{{formattedValue}}</span>
    </SiteTrafficExplorerPageviewCount>
  </label>
</template>
