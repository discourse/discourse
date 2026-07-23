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
import AdminTable from "../admin-table";
import EmptyState from "../empty-state";

const STATUS_ICONS = {
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

function isRunning(execution) {
  return ["pending", "running"].includes(execution.status);
}

function isLive(execution) {
  return isRunning(execution) || execution.status === "waiting";
}

function runTime(execution, currentTime) {
  if (isRunning(execution) && execution.started_at) {
    const ms = Math.max(0, currentTime - new Date(execution.started_at));
    return `${Math.floor(ms / 1000).toFixed(1)}s`;
  }

  const ms = execution.run_time_ms;
  if (ms == null) {
    return "—";
  }
  return ms < 1000 ? `${ms}ms` : `${(ms / 1000).toFixed(1)}s`;
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
  @tracked currentTime = Date.now();

  #subscriptions = new Map();
  #timer;

  constructor() {
    super(...arguments);
    this.loadExecutions();
  }

  willDestroy() {
    super.willDestroy(...arguments);
    for (const { channel, handler } of this.#subscriptions.values()) {
      this.messageBus.unsubscribe(channel, handler);
    }
    this.#subscriptions.clear();
    this.#stopTimer();
  }

  async loadExecutions() {
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
      this.#syncLiveExecutions();
    } catch (e) {
      if (!this.isDestroying && !this.isDestroyed) {
        popupAjaxError(e);
      }
    }
  }

  #syncLiveExecutions() {
    const liveIds = new Set(
      (this.executions || []).filter(isLive).map((execution) => execution.id)
    );

    for (const [executionId, subscription] of this.#subscriptions) {
      if (!liveIds.has(executionId)) {
        this.messageBus.unsubscribe(subscription.channel, subscription.handler);
        this.#subscriptions.delete(executionId);
      }
    }

    for (const executionId of liveIds) {
      if (this.#subscriptions.has(executionId)) {
        continue;
      }

      const channel = `/discourse-workflows/execution/${executionId}`;
      const handler = (message) => this.#handleProgress(executionId, message);
      this.#subscriptions.set(executionId, { channel, handler });
      this.messageBus.subscribe(channel, handler, 0);
    }

    if ((this.executions || []).some(isRunning)) {
      this.#startTimer();
    } else {
      this.#stopTimer();
    }
  }

  #handleProgress(executionId, message) {
    if (
      message.type !== "execution_progress" ||
      message.execution?.id !== executionId
    ) {
      return;
    }

    const current = this.executions.find(
      (execution) => execution.id === executionId
    );
    if (
      !current ||
      !Object.entries(message.execution).some(
        ([key, value]) => (current[key] ?? null) !== (value ?? null)
      )
    ) {
      return;
    }

    this.executions = this.executions.map((execution) =>
      execution.id === executionId
        ? { ...execution, ...message.execution }
        : execution
    );
    this.#syncLiveExecutions();
  }

  #startTimer() {
    this.currentTime = Date.now();
    this.#timer ||= window.setInterval(() => {
      this.currentTime = Date.now();
    }, 1000);
  }

  #stopTimer() {
    if (this.#timer) {
      window.clearInterval(this.#timer);
      this.#timer = null;
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
      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      this.executions = [...this.executions, ...result.executions];
      this.loadMoreUrl = result.meta?.load_more_executions;
      this.#syncLiveExecutions();
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
