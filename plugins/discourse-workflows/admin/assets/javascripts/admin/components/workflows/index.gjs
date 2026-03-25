import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import LoadMore from "discourse/components/load-more";
import avatar from "discourse/helpers/avatar";
import icon from "discourse/helpers/d-icon";
import formatDate from "discourse/helpers/format-date";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
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

  <template>
    {{#if @workflows.content.length}}
      <div class="workflows-index__toolbar">
        <DButton
          @action={{this.createWorkflow}}
          @label="discourse_workflows.new_workflow"
          @icon="plus"
          class="btn-primary btn-small"
        />
      </div>
    {{/if}}

    <Stats @stats={{@stats}} />

    <div class="workflows-index">
      {{#if @workflows.content.length}}
        <LoadMore @action={{this.loadMore}} @enabled={{@workflows.canLoadMore}}>
          <table class="workflows-index__table">
            <thead>
              <tr>
                <th>{{i18n "discourse_workflows.workflow_name"}}</th>
                <th>{{i18n "discourse_workflows.last_editor"}}</th>
                <th>{{i18n "discourse_workflows.last_update"}}</th>
                <th>{{i18n "discourse_workflows.last_run"}}</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {{#each @workflows.content as |workflow|}}
                <tr
                  class="workflows-index__row"
                  data-workflow-id={{workflow.id}}
                >
                  <td class="workflows-index__name">
                    <div class="workflows-index__name-content">
                      <LinkTo
                        @route="adminPlugins.show.discourse-workflows.show"
                        @model={{workflow.id}}
                        class="workflows-index__name-link"
                      >
                        {{workflow.name}}
                      </LinkTo>
                      {{#if (eq workflow.last_execution_status "error")}}
                        <span
                          class="workflows-index__warning"
                          role="img"
                          aria-label={{i18n
                            "discourse_workflows.last_execution_failed"
                          }}
                          title={{i18n
                            "discourse_workflows.last_execution_failed"
                          }}
                        >
                          {{icon "triangle-exclamation"}}
                        </span>
                      {{/if}}
                    </div>
                  </td>
                  <td class="workflows-index__last-editor">
                    {{#if workflow.updated_by}}
                      <a
                        href={{workflow.updated_by.path}}
                        class="workflows-index__last-editor-link"
                      >
                        {{avatar workflow.updated_by imageSize="tiny"}}
                        <span>{{workflow.updated_by.username}}</span>
                      </a>
                    {{/if}}
                  </td>
                  <td class="workflows-index__last-update">
                    {{formatDate workflow.updated_at format="medium"}}
                  </td>
                  <td class="workflows-index__last-run">
                    {{#if workflow.last_execution_at}}
                      {{formatDate workflow.last_execution_at format="medium"}}
                    {{/if}}
                  </td>
                  <td class="workflows-index__status">
                    {{#if workflow.enabled}}
                      <span class="workflows-index__badge --enabled">
                        {{i18n "discourse_workflows.enabled"}}
                      </span>
                    {{else}}
                      <span class="workflows-index__badge --disabled">
                        {{i18n "discourse_workflows.disabled"}}
                      </span>
                    {{/if}}
                  </td>
                </tr>
              {{/each}}
            </tbody>
          </table>
          <ConditionalLoadingSpinner @condition={{this.loading}} />
        </LoadMore>
      {{else}}
        <EmptyState
          @title={{i18n
            "discourse_workflows.empty_title"
            username=this.currentUser.username
          }}
          @description={{i18n "discourse_workflows.empty_description"}}
          @buttonLabel="discourse_workflows.create_first_workflow"
          @onAction={{this.createWorkflow}}
        />
      {{/if}}
    </div>
  </template>
}
