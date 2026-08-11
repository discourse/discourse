import Component from "@glimmer/component";
import { action } from "@ember/object";
import SiteTrafficDimensionLabel from "discourse/admin/components/site-traffic-dimension-label";
import SiteTrafficPageviewCount from "discourse/admin/components/site-traffic-pageview-count";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class SiteTrafficBreakdownModal extends Component {
  get rows() {
    return this.args.model.rows.slice(0, 50);
  }

  @action
  filterLabel(row) {
    return i18n("admin.site_traffic_explorer.filter_by", {
      label: row.label,
      count: row.pageviews,
    });
  }

  @action
  filter(row) {
    this.args.closeModal();
    this.args.model.filter(row);
  }

  <template>
    <DModal
      @title={{@model.title}}
      @closeModal={{@closeModal}}
      class="site-traffic-breakdown-modal"
    >
      <:body>
        <table class="d-table site-traffic-breakdown-modal__table">
          <thead class="d-table__header">
            <tr class="d-table__row">
              <th class="d-table__header-cell" scope="col">
                {{@model.columnLabel}}
              </th>
              <th
                class="d-table__header-cell site-traffic-breakdown-modal__pageviews"
                scope="col"
              >{{i18n "admin.site_traffic_explorer.pageviews"}}</th>
            </tr>
          </thead>
          <tbody class="d-table__body">
            {{#each this.rows as |row|}}
              <tr class="d-table__row">
                <td class="d-table__cell --overview">
                  {{#let (@model.rowLink row) as |rowLink|}}
                    {{#if rowLink}}
                      <a
                        href={{rowLink.href}}
                        rel={{rowLink.rel}}
                        target={{rowLink.target}}
                        class="site-traffic-explorer__row-link"
                      >
                        <SiteTrafficDimensionLabel
                          @dimension={{@model.dimension}}
                          @row={{row}}
                        />
                      </a>
                    {{else}}
                      <SiteTrafficDimensionLabel
                        @dimension={{@model.dimension}}
                        @row={{row}}
                      />
                    {{/if}}
                  {{/let}}
                </td>
                <td
                  class="d-table__cell --detail site-traffic-breakdown-modal__pageviews"
                >
                  <div class="d-table__mobile-label">
                    {{i18n "admin.site_traffic_explorer.pageviews"}}
                  </div>
                  <SiteTrafficPageviewCount
                    @value={{row.pageviews}}
                    as |formattedValue|
                  >
                    <DButton
                      @display="link"
                      @translatedLabel={{formattedValue}}
                      @translatedAriaLabel={{this.filterLabel row}}
                      @action={{this.filter}}
                      @actionParam={{row}}
                    />
                  </SiteTrafficPageviewCount>
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      </:body>
    </DModal>
  </template>
}
