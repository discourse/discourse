import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import getURL from "discourse/lib/get-url";
import { and, eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class SiteTrafficBreakdownModal extends Component {
  @service modal;

  get inline() {
    return !this.modal.containerElement;
  }

  get rows() {
    return this.args.model.rows.slice(0, 50);
  }

  @action
  select(row) {
    this.args.model.onSelect?.(row);
    this.args.closeModal();
  }

  <template>
    <DModal
      class="site-traffic-breakdown-modal"
      @title={{@model.title}}
      @closeModal={{@closeModal}}
      @inline={{this.inline}}
    >
      <:body>
        <table
          class="d-table site-traffic-breakdown-modal__table"
          aria-label={{@model.title}}
        >
          <thead class="d-table__header">
            <tr class="d-table__row">
              <th class="d-table__cell" scope="col">
                {{i18n "admin.dashboard.site_traffic.details.table.dimension"}}
              </th>
              <th class="d-table__cell --numeric" scope="col">
                {{i18n "admin.dashboard.site_traffic.details.table.pageviews"}}
              </th>
            </tr>
          </thead>
          <tbody class="d-table__body">
            {{#each this.rows as |row|}}
              <tr class="d-table__row">
                <td class="d-table__cell">
                  {{#if
                    (and row.filterable (eq @model.dimension "entry_urls"))
                  }}
                    <span class="site-traffic-breakdown-modal__entry-actions">
                      <a
                        href={{getURL row.value}}
                        data-auto-route="true"
                        data-test-entry-url-link
                      >{{row.displayLabel}}</a>
                      <DButton
                        @icon="filter"
                        @action={{fn this.select row}}
                        @translatedTitle={{i18n
                          "admin.dashboard.site_traffic.details.filter_row"
                          value=row.displayLabel
                        }}
                        @translatedAriaLabel={{i18n
                          "admin.dashboard.site_traffic.details.filter_row"
                          value=row.displayLabel
                        }}
                        class="site-traffic-breakdown-modal__filter btn-flat"
                        data-test-entry-url-filter
                      />
                    </span>
                  {{else if row.filterable}}
                    <button
                      type="button"
                      class="btn-flat site-traffic-breakdown-modal__filter"
                      data-test-breakdown-row
                      {{on "click" (fn this.select row)}}
                    >
                      {{row.displayLabel}}
                    </button>
                  {{else}}
                    <span data-test-breakdown-row>{{row.displayLabel}}</span>
                  {{/if}}
                </td>
                <td class="d-table__cell --numeric">
                  <span class="d-table__mobile-label">
                    {{i18n
                      "admin.dashboard.site_traffic.details.table.pageviews"
                    }}
                  </span>
                  {{row.formattedPageviews}}
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      </:body>
    </DModal>
  </template>
}
