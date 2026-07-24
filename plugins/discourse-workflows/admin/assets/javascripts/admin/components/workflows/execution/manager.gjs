import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import AdminTable from "../admin-table";
import EmptyState from "../empty-state";

const STATUS_ICONS = {
  success: "circle-check",
  error: "circle-xmark",
  running: "spinner",
  waiting: "clock",
};

function statusIcon(status) {
  return STATUS_ICONS[status] || "circle";
}

function formatTime(timestamp) {
  if (!timestamp) {
    return "—";
  }
  return new Date(timestamp).toLocaleString();
}

function runTime(execution) {
  const ms = execution.run_time_ms;
  if (ms == null) {
    return "—";
  }
  return ms < 1000 ? `${ms}ms` : `${(ms / 1000).toFixed(1)}s`;
}

export default class ExecutionsManager extends Component {
  @service currentUser;
  @service dialog;
  @service router;

  @tracked executions = null;
  @tracked loadMoreUrl = null;
  @tracked loadingMore = false;
  @tracked bulkMode = false;

  constructor() {
    super(...arguments);
    this.loadExecutions();
  }

  async loadExecutions() {
    try {
      const url = this.args.workflowId
        ? `/admin/plugins/discourse-workflows/workflows/${this.args.workflowId}/executions.json`
        : "/admin/plugins/discourse-workflows/executions.json";
      const result = await ajax(url);
      this.executions = result.executions;
      this.loadMoreUrl = result.meta?.load_more_executions;
    } catch (e) {
      popupAjaxError(e);
    }
  }

  get canLoadMore() {
    return !!this.loadMoreUrl;
  }

  @action
  async loadMore() {
    if (!this.loadMoreUrl || !this.canLoadMore || this.loadingMore) {
      return;
    }

    this.loadingMore = true;
    try {
      const result = await ajax(this.loadMoreUrl);
      this.executions = [...this.executions, ...result.executions];
      this.loadMoreUrl = result.meta?.load_more_executions;
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loadingMore = false;
    }
  }

  get isLoading() {
    return this.executions === null;
  }

  @action
  enableBulkMode() {
    this.bulkMode = true;
  }

  @action
  cancelBulkMode(clearSelection) {
    clearSelection();
    this.bulkMode = false;
  }

  @action
  showExecution(execution) {
    this.router.transitionTo(
      "adminPlugins.show.discourse-workflows.show.executions.show",
      execution.workflow_id,
      execution.id
    );
  }

  @action
  async deleteSelected(selectedIds, clearSelection) {
    const count = selectedIds.size;
    this.dialog.yesNoConfirm({
      message: i18n("discourse_workflows.executions.delete_confirm", { count }),
      didConfirm: async () => {
        try {
          await ajax("/admin/plugins/discourse-workflows/executions.json", {
            type: "DELETE",
            data: { ids: [...selectedIds] },
          });
          clearSelection();
          this.bulkMode = false;
          await this.loadExecutions();
        } catch (e) {
          popupAjaxError(e);
        }
      },
    });
  }

  <template>
    <AdminTable
      @items={{this.executions}}
      @isLoading={{this.isLoading}}
      @canLoadMore={{this.canLoadMore}}
      @loadMore={{this.loadMore}}
      @loadingMore={{this.loadingMore}}
      @selectable={{this.bulkMode}}
    >
      <:empty>
        <EmptyState
          @emoji="wave"
          @title={{i18n
            "discourse_workflows.executions.empty_title"
            username=this.currentUser.displayName
          }}
          @description={{i18n
            "discourse_workflows.executions.empty_description"
          }}
        />
      </:empty>
      <:toolbar as |toolbar|>
        {{#if this.bulkMode}}
          {{#if toolbar.hasSelection}}
            <DButton
              @action={{fn
                this.deleteSelected
                toolbar.selectedIds
                toolbar.clearSelection
              }}
              @label="discourse_workflows.executions.delete_selected"
              @icon="trash-can"
              class="btn-danger btn-small"
            />
          {{/if}}
          <DButton
            @action={{fn this.cancelBulkMode toolbar.clearSelection}}
            @label="discourse_workflows.executions.cancel_select"
            class="btn-default btn-small"
          />
        {{else}}
          <DButton
            @action={{this.enableBulkMode}}
            @label="discourse_workflows.executions.select"
            @icon="list-check"
            class="btn-default btn-small"
          />
        {{/if}}
      </:toolbar>
      <:head>
        {{#if @workflowId}}
          <th class="d-table__header-cell">{{i18n
              "discourse_workflows.executions.started_at"
            }}</th>
          <th class="d-table__header-cell">{{i18n
              "discourse_workflows.executions.status"
            }}</th>
        {{else}}
          <th class="d-table__header-cell">{{i18n
              "discourse_workflows.executions.workflow"
            }}</th>
          <th class="d-table__header-cell">{{i18n
              "discourse_workflows.executions.status"
            }}</th>
          <th class="d-table__header-cell">{{i18n
              "discourse_workflows.executions.started_at"
            }}</th>
        {{/if}}
        <th class="d-table__header-cell">{{i18n
            "discourse_workflows.executions.run_time"
          }}</th>
        <th class="d-table__header-cell"></th>
      </:head>
      <:row as |execution|>
        {{#if @workflowId}}
          <td class="d-table__cell --overview">
            {{formatTime execution.started_at}}
          </td>
          <td class="d-table__cell --detail">
            <div class="d-table__mobile-label">
              {{i18n "discourse_workflows.executions.status"}}
            </div>
            <span
              class="workflows-executions-manager__status --{{execution.status}}"
            >
              {{dIcon (statusIcon execution.status)}}
              {{i18n
                (concat
                  "discourse_workflows.executions.statuses." execution.status
                )
              }}
            </span>
          </td>
        {{else}}
          <td class="d-table__cell --overview">
            <strong
              class="d-table__overview-name"
            >{{execution.workflow_name}}</strong>
          </td>
          <td class="d-table__cell --detail">
            <div class="d-table__mobile-label">
              {{i18n "discourse_workflows.executions.status"}}
            </div>
            <span
              class="workflows-executions-manager__status --{{execution.status}}"
            >
              {{dIcon (statusIcon execution.status)}}
              {{i18n
                (concat
                  "discourse_workflows.executions.statuses." execution.status
                )
              }}
            </span>
          </td>
          <td class="d-table__cell --detail">
            <div class="d-table__mobile-label">
              {{i18n "discourse_workflows.executions.started_at"}}
            </div>
            {{formatTime execution.started_at}}
          </td>
        {{/if}}
        <td class="d-table__cell --detail">
          <div class="d-table__mobile-label">
            {{i18n "discourse_workflows.executions.run_time"}}
          </div>
          {{runTime execution}}
        </td>
        <td class="d-table__cell --controls">
          <div class="d-table__cell-actions">
            <DButton
              @action={{fn this.showExecution execution}}
              @label="discourse_workflows.executions.show"
              class="btn-default btn-small"
            />
          </div>
        </td>
      </:row>
    </AdminTable>
  </template>
}
