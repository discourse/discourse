import { array } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import boundDate from "discourse/helpers/bound-date";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <section class="user-content">
      <table class="group-reports">
        <thead>
          <th>
            {{i18n "explorer.report_name"}}
          </th>
          <th>
            {{i18n "explorer.query_description"}}
          </th>
          <th>
            {{i18n "explorer.query_time"}}
          </th>
        </thead>
        <tbody>
          {{#each @controller.model.queries as |query|}}
            <tr>
              <td>
                <LinkTo
                  @route="group.reports.show"
                  @models={{array @controller.group.name query.id}}
                >
                  {{query.name}}
                </LinkTo>
              </td>
              <td>{{query.description}}</td>
              <td>
                {{#if query.last_run_at}}
                  {{boundDate query.last_run_at}}
                {{/if}}
              </td>
            </tr>
          {{/each}}
        </tbody>
      </table>
    </section>
  </template>
);
