import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array, concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import LoadMore from "discourse/components/load-more";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import EmptyState from "../empty-state";

const indeterminate = modifier((element, [value]) => {
  element.indeterminate = value;
});

export default class ExecutionsManager extends Component {
  @service currentUser;
  @service dialog;

  @tracked executions = null;
  @tracked loadMoreUrl = null;
  @tracked totalRows = 0;
  @tracked loadingMore = false;
  @tracked selectedIds = new Set();

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

  get hasSelection() {
    return this.selectedIds.size > 0;
  }

  get allSelected() {
    return (
      this.executions?.length > 0 &&
      this.selectedIds.size === this.executions.length
    );
  }

  get headerCheckboxState() {
    if (this.selectedIds.size === 0) {
      return "none";
    }
    if (this.selectedIds.size === this.executions?.length) {
      return "all";
    }
    return "indeterminate";
  }

  @action
  isRowSelected(id) {
    return this.selectedIds.has(id);
  }

  @action
  toggleRowSelection(id) {
    const next = new Set(this.selectedIds);
    if (next.has(id)) {
      next.delete(id);
    } else {
      next.add(id);
    }
    this.selectedIds = next;
  }

  @action
  toggleAllSelection() {
    if (this.allSelected) {
      this.selectedIds = new Set();
    } else {
      this.selectedIds = new Set(this.executions.map((e) => e.id));
    }
  }

  @action
  async deleteSelected() {
    const count = this.selectedIds.size;
    this.dialog.yesNoConfirm({
      message: i18n("discourse_workflows.executions.delete_confirm", { count }),
      didConfirm: async () => {
        try {
          await ajax("/admin/plugins/discourse-workflows/executions.json", {
            type: "DELETE",
            data: { ids: [...this.selectedIds] },
          });
          this.selectedIds = new Set();
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
    <div class="workflows-executions-manager">
      <ConditionalLoadingSpinner @condition={{this.isLoading}}>
        {{#if this.executions.length}}
          {{#if this.hasSelection}}
            <div class="workflows-executions-manager__toolbar">
              <DButton
                @action={{this.deleteSelected}}
                @label="discourse_workflows.executions.delete_selected"
                @icon="trash-can"
                class="btn-danger btn-small"
              />
            </div>
          {{/if}}
          <LoadMore @action={{this.loadMore}} @enabled={{this.canLoadMore}}>
            <table class="workflows-executions-manager__table">
              <thead>
                <tr>
                  <th class="workflows-executions-manager__checkbox-cell">
                    <input
                      type="checkbox"
                      checked={{this.allSelected}}
                      {{indeterminate
                        (eq this.headerCheckboxState "indeterminate")
                      }}
                      {{on "change" this.toggleAllSelection}}
                      class="workflows-executions-manager__checkbox"
                    />
                    {{i18n "discourse_workflows.executions.id"}}
                  </th>
                  {{#unless @workflowId}}
                    <th>{{i18n "discourse_workflows.executions.workflow"}}</th>
                  {{/unless}}
                  <th>{{i18n "discourse_workflows.executions.status"}}</th>
                  <th>{{i18n "discourse_workflows.executions.started_at"}}</th>
                  <th>{{i18n "discourse_workflows.executions.run_time"}}</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {{#each this.executions as |execution|}}
                  <tr>
                    <td class="workflows-executions-manager__checkbox-cell">
                      <input
                        type="checkbox"
                        checked={{this.isRowSelected execution.id}}
                        {{on
                          "change"
                          (fn this.toggleRowSelection execution.id)
                        }}
                        class="workflows-executions-manager__checkbox"
                      />
                      {{execution.id}}
                    </td>
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
                            "discourse_workflows.executions.statuses."
                            execution.status
                          )
                        }}
                      </span>
                    </td>
                    <td>{{this.formatTime execution.started_at}}</td>
                    <td>{{this.runTime execution}}</td>
                    <td class="workflows-executions-manager__actions">
                      <LinkTo
                        @route="adminPlugins.show.discourse-workflows.show.executions.show"
                        @models={{array execution.workflow_id execution.id}}
                        class="btn btn-flat btn-small"
                      >
                        {{i18n "discourse_workflows.executions.details"}}
                      </LinkTo>
                    </td>
                  </tr>
                {{/each}}
              </tbody>
            </table>
            <ConditionalLoadingSpinner @condition={{this.loadingMore}} />
          </LoadMore>
        {{else}}
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
        {{/if}}
      </ConditionalLoadingSpinner>
    </div>
  </template>
}
