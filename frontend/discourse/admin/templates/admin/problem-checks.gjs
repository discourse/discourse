import { get } from "@ember/helper";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import formatDate from "discourse/helpers/format-date";
import { notEq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

const STATUS_CLASSES = {
  passing: "--success",
  failing: "--critical",
};

const STATUS_LABELS = {
  passing: i18n("admin.config.problem_checks.passing"),
  failing: i18n("admin.config.problem_checks.failing"),
};

export default <template>
  <div class="admin-problem-checks admin-config-page">
    <DPageHeader
      @titleLabel={{i18n "admin.config.problem_checks.title"}}
      @descriptionLabel={{i18n
        "admin.config.problem_checks.header_description"
      }}
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
        <DBreadcrumbsItem
          @path="/admin/problem-checks"
          @label={{i18n "admin.config.problem_checks.title"}}
        />
      </:breadcrumbs>
    </DPageHeader>

    <div class="admin-container admin-config-page__main-area">
      <table class="admin-problem-checks__table d-admin-table">
        <thead>
          <tr>
            <th>{{i18n "admin.config.problem_checks.status"}}</th>
            <th>{{i18n "admin.config.problem_checks.identifier"}}</th>
            <th>{{i18n "admin.config.problem_checks.target"}}</th>
            <th>{{i18n "admin.config.problem_checks.last_run_at"}}</th>
          </tr>
        </thead>
        <tbody>
          {{#each @model as |tracker|}}
            <tr class="admin-problem-checks__row --{{tracker.status}}">
              <td class="admin-problem-checks__status">
                <div class="status-label {{get STATUS_CLASSES tracker.status}}">
                  <div class="status-label-indicator"></div>
                  <div class="status-label-text">
                    {{get STATUS_LABELS tracker.status}}
                  </div>
                </div>
              </td>
              <td class="admin-problem-checks__identifier">
                {{tracker.identifier}}
              </td>
              <td class="admin-problem-checks__target">
                {{#if (notEq tracker.target "__NULL__")}}
                  <span
                    class="admin-problem-checks__target"
                  >{{tracker.target}}</span>
                {{/if}}
              </td>
              <td class="admin-problem-checks__last-run">
                {{#if tracker.last_run_at}}
                  {{formatDate tracker.last_run_at leaveAgo="true"}}
                {{/if}}
              </td>
              <td></td>
            </tr>
          {{/each}}
        </tbody>
      </table>
    </div>
  </div>
</template>
