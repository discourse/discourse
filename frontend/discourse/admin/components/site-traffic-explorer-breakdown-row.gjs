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
      aria-label={{filterLabel @row}}
      checked={{@checked}}
      class="site-traffic-explorer__row-checkbox"
      id={{@inputId}}
      type="checkbox"
      {{on "change" @onToggle}}
    />

    {{#if @rowLink}}
      {{! eslint-disable-next-line ember/template-no-nested-interactive }}
      <a
        class="site-traffic-explorer__row-link"
        href={{@rowLink.href}}
        rel={{@rowLink.rel}}
        target={{@rowLink.target}}
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

    <span class="site-traffic-explorer__row-count">
      <SiteTrafficExplorerPageviewCount
        @value={{@row.pageviews}}
        as |formattedValue|
      >
        {{formattedValue}}
      </SiteTrafficExplorerPageviewCount>
    </span>
  </label>
</template>
