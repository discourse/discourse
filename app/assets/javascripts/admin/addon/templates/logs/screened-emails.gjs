import { fn } from "@ember/helper";
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
        "admin.config.staff_action_logs.sub_pages.screened_emails.header_description"
      }}
    />

    <DButton
      @action={{@controller.exportScreenedEmailList}}
      @title="admin.export_csv.button_title.screened_email"
      @icon="download"
      @label="admin.export_csv.button_text"
      class="btn-default screened-email-export"
    />

    <br />

    <ConditionalLoadingSpinner @condition={{@controller.loading}}>
      {{#if @controller.model.length}}

        <table class="screened-emails grid">
          <thead>
            <th class="first email">{{i18n
                "admin.logs.screened_emails.email"
              }}</th>
            <th class="action">{{i18n "admin.logs.action"}}</th>
            <th class="match_count">{{i18n "admin.logs.match_count"}}</th>
            <th class="last_match_at">{{i18n "admin.logs.last_match_at"}}</th>
            <th class="created_at">{{i18n "admin.logs.created_at"}}</th>
            <th class="ip_address">{{i18n "admin.logs.ip_address"}}</th>
            <th class="action"></th>
          </thead>
          <tbody>
            {{#each @controller.model as |item|}}
              <tr class="admin-list-item">
                <td class="col first email">
                  <div
                    class="overflow-ellipsis"
                    title={{item.email}}
                  >{{item.email}}</div>
                </td>
                <td class="action">{{item.actionName}}</td>
                <td class="match_count"><div class="label">{{i18n
                      "admin.logs.match_count"
                    }}</div>{{item.match_count}}</td>
                <td class="last_match_at"><div class="label">{{i18n
                      "admin.logs.last_match_at"
                    }}</div>{{ageWithTooltip item.last_match_at}}</td>
                <td class="created_at"><div class="label">{{i18n
                      "admin.logs.created_at"
                    }}</div>{{ageWithTooltip item.created_at}}</td>
                <td class="ip_address">{{item.ip_address}}</td>
                <td class="action">
                  <DButton
                    @action={{fn @controller.clearBlock item}}
                    @icon="check"
                    @label="admin.logs.screened_emails.actions.allow"
                  />
                </td>
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
