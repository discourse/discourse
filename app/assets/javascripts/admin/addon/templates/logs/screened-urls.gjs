import RouteTemplate from "ember-route-template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import DPageSubheader from "discourse/components/d-page-subheader";
import ageWithTooltip from "discourse/helpers/age-with-tooltip";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <DPageSubheader
      @descriptionLabel={{i18n
        "admin.config.staff_action_logs.sub_pages.screened_urls.header_description"
      }}
    />

    <DButton
      @action={{@controller.exportScreenedUrlList}}
      @title="admin.export_csv.button_title.screened_url"
      @icon="download"
      @label="admin.export_csv.button_text"
      class="btn-default"
    />
    <br />

    <ConditionalLoadingSpinner @condition={{@controller.loading}}>
      {{#if @controller.model.length}}
        <table class="screened-urls grid">
          <thead>
            <th class="first domain">{{i18n
                "admin.logs.screened_urls.domain"
              }}</th>
            <th class="action">{{i18n "admin.logs.action"}}</th>
            <th class="match_count">{{i18n "admin.logs.match_count"}}</th>
            <th class="last_match_at">{{i18n "admin.logs.last_match_at"}}</th>
            <th class="created_at">{{i18n "admin.logs.created_at"}}</th>
          </thead>
          <tbody>
            {{#each @controller.model as |url|}}
              <tr class="admin-list-item">
                <td class="col first domain">
                  <div
                    class="overflow-ellipsis"
                    title={{url.domain}}
                  >{{url.domain}}</div>
                </td>
                <td class="col action">{{url.actionName}}</td>
                <td class="col match_count"><div class="label">{{i18n
                      "admin.logs.match_count"
                    }}</div>{{url.match_count}}</td>
                <td class="col last_match_at"><div class="label">{{i18n
                      "admin.logs.last_match_at"
                    }}</div>{{ageWithTooltip url.last_match_at}}</td>
                <td class="col created_at"><div class="label">{{i18n
                      "admin.logs.created_at"
                    }}</div>{{ageWithTooltip url.created_at}}</td>
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
