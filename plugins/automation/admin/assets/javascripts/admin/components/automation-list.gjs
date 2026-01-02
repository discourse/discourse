import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import DButton from "discourse/components/d-button";
import DPageSubheader from "discourse/components/d-page-subheader";
import avatar from "discourse/helpers/avatar";
import formatDate from "discourse/helpers/format-date";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { removeValueFromArray } from "discourse/lib/array-tools";
import { escapeExpression } from "discourse/lib/utilities";
import { or } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import AutomationEnabledToggle from "discourse/plugins/automation/admin/components/automation-enabled-toggle";

// number of runs required to show the runs count for the period
const RUN_THRESHOLD = 10;

export default class AutomationList extends Component {
  @service dialog;

  @action
  async destroyAutomation(automation) {
    automation.set("isDeleting", true);
    try {
      await this.dialog.deleteConfirm({
        message: i18n("discourse_automation.destroy_automation.confirm", {
          name: escapeExpression(automation.name),
        }),
        didConfirm: () => {
          try {
            automation.destroyRecord();
            removeValueFromArray(this.args.model.content, automation);
            automation = null;
          } catch (e) {
            popupAjaxError(e);
          }
        },
      });
    } finally {
      automation?.set("isDeleting", false);
    }
  }

  @action
  async toggleEnabled(automation) {
    automation.set("enabled", !automation.enabled);
    try {
      await automation.save({ enabled: automation.enabled });
    } catch (e) {
      popupAjaxError(e);
      automation.set("enabled", !automation.enabled);
    }
  }

  statsText(stats) {
    if (!stats || !stats.last_month || stats.last_month.total_runs === 0) {
      return "-";
    }

    if (stats.last_day?.total_runs > RUN_THRESHOLD) {
      return i18n("discourse_automation.models.automation.runs_today", {
        count: stats.last_day.total_runs,
      });
    }

    if (stats.last_week?.total_runs > RUN_THRESHOLD) {
      return i18n("discourse_automation.models.automation.runs_this_week", {
        count: stats.last_week.total_runs,
      });
    }

    return i18n("discourse_automation.models.automation.runs_this_month", {
      count: stats.last_month.total_runs,
    });
  }

  recentErrorsCount(stats) {
    return stats?.last_day?.total_errors || 0;
  }

  <template>
    <section class="discourse-automations-table">
      <DPageSubheader @titleLabel={{i18n "discourse_automation.table_title"}}>
        <:actions as |actions|>
          <actions.Primary
            @label="discourse_automation.create"
            @route="adminPlugins.show.automation.new"
            @icon="plus"
            class="discourse-automation__create-btn"
          />
        </:actions>
      </DPageSubheader>

      {{#if @model.content.length}}
        <table class="d-admin-table automations">
          <thead>
            <tr>
              <th>{{i18n
                  "discourse_automation.models.automation.name.label"
                }}</th>
              <th>{{i18n
                  "discourse_automation.models.automation.last_updated_by.label"
                }}</th>
              <th>{{i18n
                  "discourse_automation.models.automation.runs.label"
                }}</th>
              <th>{{i18n
                  "discourse_automation.models.automation.last_run.label"
                }}</th>
              <th>{{i18n
                  "discourse_automation.models.automation.enabled.label"
                }}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {{#each @model.content as |automation|}}
              <tr class="d-admin-row__content">
                {{#if automation.script.not_found}}
                  <td
                    colspan="5"
                    class="d-admin-row__detail alert alert-danger"
                  >
                    <div class="d-admin-row__mobile-label">
                      {{i18n
                        "discourse_automation.models.automation.status.label"
                      }}
                    </div>
                    {{i18n
                      "discourse_automation.scriptables.not_found"
                      script=automation.script.id
                      automation=automation.name
                    }}
                  </td>
                {{else if automation.trigger.not_found}}
                  <td
                    colspan="5"
                    class="d-admin-row__detail alert alert-danger"
                  >
                    <div class="d-admin-row__mobile-label">
                      {{i18n
                        "discourse_automation.models.automation.status.label"
                      }}
                    </div>
                    {{i18n
                      "discourse_automation.triggerables.not_found"
                      trigger=automation.trigger.id
                      automation=automation.name
                    }}
                  </td>
                {{else}}
                  <td class="d-admin-row__overview automations__name">
                    {{if
                      automation.name
                      automation.name
                      (i18n "discourse_automation.unnamed_automation")
                    }}
                  </td>
                  <td class="d-admin-row__detail automations__updated-by">
                    <div class="d-admin-row__mobile-label">
                      {{i18n
                        "discourse_automation.models.automation.last_updated_by.label"
                      }}
                    </div>
                    <div class="automations__user-timestamp">
                      <a
                        href={{automation.last_updated_by.userPath}}
                        data-user-card={{automation.last_updated_by.username}}
                      >
                        {{avatar automation.last_updated_by imageSize="small"}}
                      </a>
                      {{formatDate automation.updated_at leaveAgo="true"}}
                    </div>
                  </td>
                  <td class="d-admin-row__detail automations__runs">
                    <div class="d-admin-row__mobile-label">
                      {{i18n
                        "discourse_automation.models.automation.runs.label"
                      }}
                    </div>
                    <span class="automations__stats">
                      {{this.statsText automation.stats}}
                    </span>
                    {{#if (this.recentErrorsCount automation.stats)}}
                      <a
                        href="/logs?search=discourse-automation"
                        class="automations__errors"
                        data-auto-route="true"
                      >
                        {{i18n
                          "discourse_automation.models.automation.recent_errors"
                          count=(this.recentErrorsCount automation.stats)
                        }}
                      </a>
                    {{/if}}
                  </td>
                  <td class="d-admin-row__detail automations__last-run">
                    <div class="d-admin-row__mobile-label">
                      {{i18n
                        "discourse_automation.models.automation.last_run.label"
                      }}
                    </div>
                    {{#if automation.stats.last_run_at}}
                      {{formatDate
                        automation.stats.last_run_at
                        leaveAgo="true"
                      }}
                    {{else}}
                      -
                    {{/if}}
                  </td>
                  <td class="d-admin-row__detail automations__enabled">
                    <div class="d-admin-row__mobile-label">
                      {{i18n
                        "discourse_automation.models.automation.enabled.label"
                      }}
                    </div>
                    <span class="enabled-toggle-with-tooltip">
                      <AutomationEnabledToggle
                        @automation={{automation}}
                        @canBeEnabled={{or
                          automation.enabled
                          automation.canBeEnabled
                        }}
                        @onToggle={{fn this.toggleEnabled automation}}
                      />
                    </span>
                  </td>
                {{/if}}

                <td class="d-admin-row__controls automations__controls">
                  <LinkTo
                    @route="adminPlugins.show.automation.edit"
                    @model={{automation.id}}
                    class="btn btn-default btn-text btn-small"
                  >
                    {{i18n "discourse_automation.edit"}}
                  </LinkTo>

                  <DButton
                    @icon="trash-can"
                    @disabled={{automation.isDeleting}}
                    {{on "click" (fn this.destroyAutomation automation)}}
                    class="btn-small btn-danger automations__delete"
                  />
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      {{else}}
        <AdminConfigAreaEmptyList
          @ctaLabel="discourse_automation.create"
          @ctaRoute="adminPlugins.show.automation.new"
          @ctaClass="discourse-automation__create-btn"
          @emptyLabel="discourse_automation.no_automation_yet"
        />
      {{/if}}
    </section>
  </template>
}
