import { fn, hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";
import PeriodChooser from "select-kit/components/period-chooser";

export default RouteTemplate(
  <template>
    <div class="admin-title">
      <PeriodChooser
        @period={{@controller.period}}
        @onChange={{fn (mut @controller.period)}}
      />
      <ComboBox
        @content={{@controller.searchTypeOptions}}
        @value={{@controller.searchType}}
        @onChange={{fn (mut @controller.searchType)}}
        class="search-logs-filter"
      />
    </div>

    <ConditionalLoadingSpinner @condition={{@controller.loading}}>
      {{#if @controller.model.length}}

        <table class="search-logs-list grid">
          <thead>
            <th class="col heading term">{{i18n
                "admin.logs.search_logs.term"
              }}</th>
            <th class="col heading">{{i18n
                "admin.logs.search_logs.searches"
              }}</th>
            <th class="col heading">{{i18n
                "admin.logs.search_logs.click_through_rate"
              }}</th>
          </thead>
          <tbody>
            {{#each @controller.model as |item|}}
              <tr class="admin-list-item">
                <td class="col term">
                  <LinkTo
                    @route="adminSearchLogs.term"
                    @query={{hash term=item.term period=@controller.period}}
                    class="test"
                  >
                    {{item.term}}
                  </LinkTo>
                </td>
                <td class="col"><div class="label">{{i18n
                      "admin.logs.search_logs.searches"
                    }}</div>{{item.searches}}</td>
                <td class="col"><div class="label">{{i18n
                      "admin.logs.search_logs.click_through_rate"
                    }}</div>{{item.ctr}}%</td>
              </tr>
            {{/each}}
          </tbody>
        </table>

      {{else}}
        {{i18n "search.no_results"}}
      {{/if}}
    </ConditionalLoadingSpinner>
  </template>
);
