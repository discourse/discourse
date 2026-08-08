import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import SiteTrafficDimensionLabel from "discourse/admin/components/site-traffic-dimension-label";
import DModal from "discourse/ui-kit/d-modal";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class SiteTrafficBreakdownModal extends Component {
  @action
  filterLabel(label) {
    return i18n("admin.site_traffic_explorer.filter_by", { label });
  }

  <template>
    <DModal
      @inline={{true}}
      @title={{@title}}
      @closeModal={{@close}}
      class="site-traffic-explorer__modal"
    >
      <:body>
        <table class="site-traffic-explorer__table">
          <thead>
            <tr>
              <th scope="col">{{@title}}</th>
              <th scope="col">{{i18n
                  "admin.site_traffic_explorer.pageviews"
                }}</th>
              <th scope="col"><span class="sr-only">{{i18n
                    "admin.site_traffic_explorer.actions"
                  }}</span></th>
            </tr>
          </thead>
          <tbody>
            {{#each @rows as |row|}}
              <tr>
                <td>
                  {{#if @link}}
                    <a href={{row.value}}>
                      <SiteTrafficDimensionLabel
                        @dimension={{@dimension}}
                        @row={{row}}
                      />
                    </a>
                  {{else}}
                    <SiteTrafficDimensionLabel
                      @dimension={{@dimension}}
                      @row={{row}}
                    />
                  {{/if}}
                </td>
                <td>{{row.pageviews}}</td>
                <td>
                  <button
                    type="button"
                    class="btn-flat"
                    aria-label={{this.filterLabel row.label}}
                    {{on "click" (fn @filter row)}}
                  >
                    {{dIcon "filter"}}
                  </button>
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      </:body>
    </DModal>
  </template>
}
