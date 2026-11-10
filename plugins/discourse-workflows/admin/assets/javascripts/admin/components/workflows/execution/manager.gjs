import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array, concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
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
} from "../../../lib/workflows/execution-progress.js";
import AdminTable from "../admin-table.gjs";
import EmptyState from "../empty-state.gjs";

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

function hasModeBadge(execution) {
  return execution.execution_mode && execution.execution_mode !== "normal";
}

function formatTime(timestamp) {
  if (!timestamp) {
    return "—";
  }

  const date = new Date(timestamp);
  return date.toLocaleString(undefined, {
    year:
      date.getFullYear() === new Date().getFullYear() ? undefined : "numeric",
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
    second: "2-digit",
  });
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
  @service workflowsNodeTypes;

  @tracked executions = null;
  @tracked loadMoreUrl = null;
  @tracked loadingMore = false;
  @tracked bulkMode = false;

  triggerIcon = (trigger) => {
    if (!this.workflowsNodeTypes.nodeTypes) {
      return "bolt";
    }

    return this.workflowsNodeTypes.findNodeType(trigger.type)?.icon || "bolt";
  };

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
    this.workflowsNodeTypes.load();
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.#progress.destroy();
  }

  get currentTime() {
    return this.#progress.currentTime;
  }

  get canLoadMore() {
    return !!this.loadMoreUrl;
  }

  get isLoading() {
    return this.executions === null;
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
      if (this.isDestroying) {
        return;
      }

      this.executions = result.executions;
      this.loadMoreUrl = result.meta?.load_more_executions;
      this.#progress.resetRetry();
      this.#progress.lastMessageId = result.meta?.message_bus_last_id ?? 0;
      this.#progress.subscribe(EXECUTIONS_CHANNEL);
      this.#syncTimer();
    } catch (error) {
      if (!this.isDestroying) {
        this.#progress.scheduleRetry(error);
      }
    } finally {
      this.#loading = false;
    }
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
      if (this.isDestroying || loadMoreToken !== this.#loadMoreToken) {
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
      if (!this.isDestroying) {
        popupAjaxError(e);
      }
    } finally {
      if (!this.isDestroying) {
        this.loadingMore = false;
      }
    }
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

  <template>
    <AdminTable
      @canLoadMore={{this.canLoadMore}}
      @isLoading={{this.isLoading}}
      @items={{this.executions}}
      @loadingMore={{this.loadingMore}}
      @loadMore={{this.loadMore}}
      @rowClass="workflows-executions-manager__row"
      @selectable={{this.bulkMode}}
    >
      <:empty>
        <EmptyState
          @description={{i18n
            "discourse_workflows.executions.empty_description"
          }}
          @emoji="wave"
          @title={{i18n
            "discourse_workflows.executions.empty_title"
            username=this.currentUser.displayName
          }}
        />
      </:empty>
      <:toolbar as |toolbar|>
        {{#if this.bulkMode}}
          {{#if toolbar.hasSelection}}
            <DButton
              class="btn-danger btn-small"
              @action={{fn
                this.deleteSelected
                toolbar.selectedIds
                toolbar.clearSelection
              }}
              @icon="trash-can"
              @label="discourse_workflows.executions.delete_selected"
            />
          {{/if}}
          <DButton
            class="btn-default btn-small"
            @action={{fn this.cancelBulkMode toolbar.clearSelection}}
            @label="discourse_workflows.executions.cancel_select"
          />
        {{else}}
          <DButton
            class="btn-default btn-small"
            @action={{this.enableBulkMode}}
            @icon="list-check"
            @label="discourse_workflows.executions.select"
          />
        {{/if}}
      </:toolbar>
      <:head>
        <th class="d-table__header-cell">{{i18n
            (if
              @workflowId
              "discourse_workflows.executions.execution"
              "discourse_workflows.executions.workflow"
            )
          }}</th>
        <th class="d-table__header-cell">{{i18n
            "discourse_workflows.executions.status"
          }}</th>
        <th class="d-table__header-cell">{{i18n
            "discourse_workflows.executions.started_at"
          }}</th>
        <th class="d-table__header-cell">{{i18n
            "discourse_workflows.executions.run_time"
          }}</th>
        <th class="d-table__header-cell"></th>
      </:head>
      <:row as |execution|>
        <td class="d-table__cell --overview">
          {{#if @workflowId}}
            <LinkTo
              class="d-table__overview-link workflows-executions-manager__execution-link"
              @models={{array execution.workflow_id execution.id}}
              @route="adminPlugins.show.discourse-workflows.show.executions.show"
            >
              <strong class="d-table__overview-name">#{{execution.id}}</strong>
            </LinkTo>
          {{else}}
            <LinkTo
              class="d-table__overview-link workflows-executions-manager__workflow-link"
              @model={{execution.workflow_id}}
              @route="adminPlugins.show.discourse-workflows.show"
            >
              <strong
                class="d-table__overview-name"
              >{{execution.workflow_name}}</strong>
            </LinkTo>
          {{/if}}
          <div class="workflows-executions-manager__meta">
            {{#unless @workflowId}}
              <LinkTo
                class="workflows-executions-manager__id workflows-executions-manager__execution-link"
                @models={{array execution.workflow_id execution.id}}
                @route="adminPlugins.show.discourse-workflows.show.executions.show"
              >#{{execution.id}}</LinkTo>
            {{/unless}}
            {{#if execution.trigger}}
              <span class="workflows-executions-manager__trigger">
                {{dIcon (this.triggerIcon execution.trigger)}}
                <span
                  class="workflows-executions-manager__trigger-name"
                >{{execution.trigger.name}}</span>
              </span>
            {{/if}}
            {{#if (hasModeBadge execution)}}
              <span
                class="workflows-executions-manager__mode --{{execution.execution_mode}}"
              >{{i18n
                  (concat
                    "discourse_workflows.executions.modes."
                    execution.execution_mode
                  )
                }}</span>
            {{/if}}
          </div>
          {{#if execution.error}}
            <div
              class="workflows-executions-manager__error"
              title={{execution.error}}
            >{{execution.error}}</div>
          {{/if}}
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
        <td
          class="d-table__cell --detail workflows-executions-manager__started"
        >
          <div class="d-table__mobile-label">
            {{i18n "discourse_workflows.executions.started_at"}}
          </div>
          {{formatTime execution.started_at}}
        </td>
        <td
          class="d-table__cell --detail workflows-executions-manager__run-time"
        >
          <div class="d-table__mobile-label">
            {{i18n "discourse_workflows.executions.run_time"}}
          </div>
          {{runTime execution this.currentTime}}
        </td>
        <td
          class="d-table__cell --controls workflows-executions-manager__chevron"
        >
          {{dIcon "chevron-right"}}
        </td>
      </:row>
    </AdminTable>
  </template>
}
