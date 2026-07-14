import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import AdminTable from "./admin-table";
import EmptyState from "./empty-state";
import Stats from "./stats";

export default class WorkflowsIndex extends Component {
  @service currentUser;
  @service router;

  @tracked loading = false;

  @action
  async loadMore() {
    if (!this.args.workflows.canLoadMore || this.loading) {
      return;
    }

    this.loading = true;
    try {
      await this.args.workflows.loadMore();
    } finally {
      this.loading = false;
    }
  }

  @action
  async createWorkflow() {
    try {
      const result = await ajax(
        "/admin/plugins/discourse-workflows/workflows.json",
        {
          type: "POST",
          data: {
            workflow: {
              name: i18n("discourse_workflows.default_workflow_name"),
            },
          },
        }
      );
      this.router.transitionTo(
        "adminPlugins.show.discourse-workflows.show",
        result.workflow.id
      );
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  workflowStatusLabel(workflow) {
    if (workflow.activeVersionId && workflow.hasUnpublishedChanges) {
      return "discourse_workflows.unpublished_changes";
    }

    return workflow.activeVersionId
      ? "discourse_workflows.published"
      : "discourse_workflows.unpublished";
  }

  @action
  workflowStatusClass(workflow) {
    if (workflow.activeVersionId && workflow.hasUnpublishedChanges) {
      return "is-unpublished-changes";
    }

    return workflow.activeVersionId ? "is-published" : "is-unpublished";
  }

  <template>
    <Stats @stats={{@stats}} />

    <AdminTable
      @items={{@workflows.content}}
      @isLoading={{false}}
      @canLoadMore={{@workflows.canLoadMore}}
      @loadMore={{this.loadMore}}
      @loadingMore={{this.loading}}
      @rowClass="workflows-index__row"
    >
      <:empty>
        <EmptyState
          @emoji="wave"
          @title={{i18n
            "discourse_workflows.empty_title"
            username=this.currentUser.displayName
          }}
          @description={{i18n "discourse_workflows.empty_description"}}
          @buttonLabel="discourse_workflows.create_first_workflow"
          @onAction={{this.createWorkflow}}
        />
      </:empty>
      <:toolbar>
        <DButton
          @action={{this.createWorkflow}}
          @label="discourse_workflows.new_workflow"
          @icon="plus"
          class="btn-primary btn-small"
        />
      </:toolbar>
      <:head>
        <th class="d-table__header-cell">{{i18n
            "discourse_workflows.creator"
          }}</th>
        <th class="d-table__header-cell">{{i18n
            "discourse_workflows.workflow_name"
          }}</th>
        <th class="d-table__header-cell">{{i18n
            "discourse_workflows.last_editor"
          }}</th>
        <th class="d-table__header-cell">{{i18n
            "discourse_workflows.last_update"
          }}</th>
        <th class="d-table__header-cell">{{i18n
            "discourse_workflows.last_run"
          }}</th>
        <th class="d-table__header-cell">{{i18n
            "discourse_workflows.status"
          }}</th>
      </:head>
      <:row as |workflow|>
        <td class="d-table__cell --detail workflows-index__creator">
          <div class="d-table__mobile-label">
            {{i18n "discourse_workflows.creator"}}
          </div>
          {{#if workflow.createdBy}}
            <a
              href={{workflow.createdBy.path}}
              class="workflows-index__creator-link"
            >
              {{dAvatar workflow.createdBy imageSize="tiny"}}
            </a>
          {{/if}}
        </td>
        <td class="d-table__cell --overview workflows-index__name">
          <LinkTo
            @route="adminPlugins.show.discourse-workflows.show"
            @model={{workflow.id}}
            class="d-table__overview-link"
          >
            <strong class="d-table__overview-name">{{workflow.name}}</strong>
            {{#if (eq workflow.lastExecutionStatus "error")}}
              <span
                class="workflows-index__warning"
                role="img"
                aria-label={{i18n "discourse_workflows.last_execution_failed"}}
                title={{i18n "discourse_workflows.last_execution_failed"}}
              >
                {{dIcon "triangle-exclamation"}}
              </span>
            {{/if}}
          </LinkTo>
        </td>
        <td class="d-table__cell --detail workflows-index__last-editor">
          <div class="d-table__mobile-label">
            {{i18n "discourse_workflows.last_editor"}}
          </div>
          {{#if workflow.updatedBy}}
            <a
              href={{workflow.updatedBy.path}}
              class="workflows-index__last-editor-link"
            >
              {{dAvatar workflow.updatedBy imageSize="tiny"}}
              <span>{{workflow.updatedBy.username}}</span>
            </a>
          {{/if}}
        </td>
        <td class="d-table__cell --detail workflows-index__last-update">
          <div class="d-table__mobile-label">
            {{i18n "discourse_workflows.last_update"}}
          </div>
          {{dFormatDate workflow.updatedAt format="medium"}}
        </td>
        <td class="d-table__cell --detail workflows-index__last-run">
          <div class="d-table__mobile-label">
            {{i18n "discourse_workflows.last_run"}}
          </div>
          {{#if workflow.lastExecutionAt}}
            {{dFormatDate workflow.lastExecutionAt format="medium"}}
          {{else}}
            {{i18n "discourse_workflows.last_execution_never"}}
          {{/if}}
        </td>
        <td class="d-table__cell --detail">
          <div class="d-table__mobile-label">
            {{i18n "discourse_workflows.status"}}
          </div>
          <span
            class={{dConcatClass
              "workflows-index__badge"
              (this.workflowStatusClass workflow)
            }}
          >
            {{i18n (this.workflowStatusLabel workflow)}}
          </span>
        </td>
      </:row>
    </AdminTable>
  </template>
}
