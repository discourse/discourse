import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array, concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import AdminTable from "../admin-table";
import EmptyState from "../empty-state";

export default class ExecutionsManager extends Component {
  @service currentUser;
  @service dialog;

  @tracked executions = null;
  @tracked loadMoreUrl = null;
  @tracked totalRows = 0;
  @tracked loadingMore = false;

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
      this.totalRows =
        result.meta?.total_rows_executions ?? result.executions.length;
    } catch (e) {
      popupAjaxError(e);
    }
  }

  get canLoadMore() {
    return this.executions && this.executions.length < this.totalRows;
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
      this.totalRows = result.meta?.total_rows_executions ?? this.totalRows;
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
          await this.loadExecutions();
        } catch (e) {
          popupAjaxError(e);
        }
      },
    });
  }

  statusIcon(status) {
    switch (status) {
      case "success":
        return "circle-check";
      case "error":
        return "circle-xmark";
      case "running":
        return "spinner";
      case "waiting":
        return "clock";
      default:
        return "circle";
    }
  }

  formatTime(timestamp) {
    if (!timestamp) {
      return "—";
    }
    return new Date(timestamp).toLocaleString();
  }

  runTime(execution) {
    const ms = execution.run_time_ms;
    if (ms == null) {
      return "—";
    }
    if (ms < 1000) {
      return `${ms}ms`;
    }
    return `${(ms / 1000).toFixed(1)}s`;
  }

  <template>
    <AdminTable
      @items={{this.executions}}
      @isLoading={{this.isLoading}}
      @canLoadMore={{this.canLoadMore}}
      @loadMore={{this.loadMore}}
      @loadingMore={{this.loadingMore}}
      @selectable={{true}}
    >
      <:empty>
        <EmptyState
          @emoji="👋"
          @title={{i18n
            "discourse_workflows.executions.empty_title"
            username=this.currentUser.username
          }}
          @description={{i18n
            "discourse_workflows.executions.empty_description"
          }}
        />
      </:empty>
      <:toolbar as |toolbar|>
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
          <DButton
            @action={{toolbar.clearSelection}}
            @icon="xmark"
            @label="discourse_workflows.executions.clear_selection"
            class="btn-default btn-small"
          />
        {{/if}}
      </:toolbar>
      <:head>
        {{#unless @workflowId}}
          <th>{{i18n "discourse_workflows.executions.workflow"}}</th>
        {{/unless}}
        <th>{{i18n "discourse_workflows.executions.status"}}</th>
        <th>{{i18n "discourse_workflows.executions.started_at"}}</th>
        <th>{{i18n "discourse_workflows.executions.run_time"}}</th>
        <th></th>
      </:head>
      <:row as |execution|>
        {{#unless @workflowId}}
          <td>
            <LinkTo
              @route="adminPlugins.show.discourse-workflows.show"
              @model={{execution.workflow_id}}
            >{{execution.workflow_name}}</LinkTo>
          </td>
        {{/unless}}
        <td>
          <span
            class="workflows-executions-manager__status --{{execution.status}}"
          >
            {{icon (this.statusIcon execution.status)}}
            {{i18n
              (concat
                "discourse_workflows.executions.statuses." execution.status
              )
            }}
          </span>
        </td>
        <td>{{this.formatTime execution.started_at}}</td>
        <td>{{this.runTime execution}}</td>
        <td class="workflows-admin-table__actions">
          <LinkTo
            @route="adminPlugins.show.discourse-workflows.show.executions.show"
            @models={{array execution.workflow_id execution.id}}
            class="btn btn-flat btn-small"
          >
            {{i18n "discourse_workflows.executions.details"}}
          </LinkTo>
        </td>
      </:row>
    </AdminTable>
  </template>
}
