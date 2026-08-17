import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dLoadingSpinner from "discourse/ui-kit/helpers/d-loading-spinner";
import { i18n } from "discourse-i18n";
import {
  ExecutionProgressStream,
  formatDuration,
  isRunning,
} from "../../../lib/workflows/execution-progress";
import AdminTable from "../admin-table";
import EmptyState from "../empty-state";

const EXECUTIONS_CHANNEL = "/discourse-workflows/executions";

const STATUS_ICONS = {
  pending: "clock",
  success: "circle-check",
  error: "circle-xmark",
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

function runTime(execution, currentTime) {
  if (isRunning(execution)) {
    return formatDuration(execution.started_at, null, currentTime);
  }

  const milliseconds = execution.run_time_ms;
  if (milliseconds == null) {
    return "—";
  }
  return milliseconds < 1000
    ? `${milliseconds}ms`
    : `${(milliseconds / 1000).toFixed(1)}s`;
}

export default class ExecutionsManager extends Component {
  @service currentUser;
  @service dialog;
  @service messageBus;
  @service router;

  @tracked executions = null;
  @tracked loadMoreUrl = null;
  @tracked loadingMore = false;
  @tracked bulkMode = false;

  #loadMoreToken = 0;
  #loading = false;
  #progress;

  constructor() {
    super(...arguments);
    this.#progress = new ExecutionProgressStream(this.messageBus, {
      onMessage: (message) => this.#applyProgress(message),
      onGap: () => this.loadExecutions(),
      onRetry: () => this.loadExecutions(),
    });
    this.loadExecutions();
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.#progress.destroy();
  }

  get currentTime() {
    return this.#progress.currentTime;
  }

  async loadExecutions() {
    if (this.#loading) {
      return;
    }

    this.#loading = true;
    this.#loadMoreToken++;
    this.#progress.unsubscribe();

    try {
      const url = this.args.workflowId
        ? `/admin/plugins/discourse-workflows/workflows/${this.args.workflowId}/executions.json`
        : "/admin/plugins/discourse-workflows/executions.json";
      const result = await ajax(url);
      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      this.executions = result.executions;
      this.loadMoreUrl = result.meta?.load_more_executions;
      this.#progress.resetRetry();
      this.#progress.lastMessageId = result.meta?.message_bus_last_id ?? 0;
      this.#progress.subscribe(EXECUTIONS_CHANNEL);
      this.#syncTimer();
    } catch (error) {
      if (!this.isDestroying && !this.isDestroyed) {
        this.#progress.scheduleRetry(error);
      }
    } finally {
      this.#loading = false;
    }
  }

  #applyProgress(message) {
    if (!this.executions) {
      this.loadExecutions();
      return;
    }

    if (
      !["execution_created", "execution_update"].includes(message.type) ||
      !message.execution
    ) {
      return;
    }

    const update = message.execution;
    if (
      this.args.workflowId &&
      update.workflow_id !== Number(this.args.workflowId)
    ) {
      return;
    }

    const current = this.executions.find(
      (execution) => execution.id === update.id
    );
    if (current) {
      this.executions = this.executions.map((execution) =>
        execution.id === update.id ? { ...execution, ...update } : execution
      );
    } else if (message.type === "execution_created") {
      this.executions = [...this.executions, update].sort(
        (left, right) => right.id - left.id
      );
    }
    this.#syncTimer();
  }

  #syncTimer() {
    if ((this.executions || []).some(isRunning)) {
      this.#progress.startTicker();
    } else {
      this.#progress.stopTicker();
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
    const loadMoreToken = ++this.#loadMoreToken;
    try {
      const result = await ajax(this.loadMoreUrl);
      if (
        this.isDestroying ||
        this.isDestroyed ||
        loadMoreToken !== this.#loadMoreToken
      ) {
        return;
      }

      const existingIds = new Set(
        this.executions.map((execution) => execution.id)
      );
      this.executions = [
        ...this.executions,
        ...result.executions.filter(
          (execution) => !existingIds.has(execution.id)
        ),
      ];
      this.loadMoreUrl = result.meta?.load_more_executions;
      this.#syncTimer();
    } catch (e) {
      if (!this.isDestroying && !this.isDestroyed) {
        popupAjaxError(e);
      }
    } finally {
      if (!this.isDestroying && !this.isDestroyed) {
        this.loadingMore = false;
      }
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
              {{#if (isRunning execution)}}
                {{dLoadingSpinner size="small"}}
              {{else}}
                {{dIcon (statusIcon execution.status)}}
              {{/if}}
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
              {{#if (isRunning execution)}}
                {{dLoadingSpinner size="small"}}
              {{else}}
                {{dIcon (statusIcon execution.status)}}
              {{/if}}
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
        <td
          class="d-table__cell --detail workflows-executions-manager__run-time"
        >
          <div class="d-table__mobile-label">
            {{i18n "discourse_workflows.executions.run_time"}}
          </div>
          {{runTime execution this.currentTime}}
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
