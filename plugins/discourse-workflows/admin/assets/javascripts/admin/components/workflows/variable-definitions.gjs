import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import { workflowVariableTypeLabel } from "../../lib/workflows/variable-types";

export default class WorkflowVariableDefinitions extends Component {
  @service dialog;

  get variables() {
    return this.args.workflow.variables;
  }

  @action
  async delete(variable) {
    const confirmed = await this.dialog.confirm({
      message: i18n("discourse_workflows.workflow_variables.delete_confirm", {
        label: variable.label,
      }),
      confirmButtonLabel: "discourse_workflows.delete",
      cancelButtonLabel: "discourse_workflows.cancel",
    });

    if (!confirmed) {
      return;
    }

    try {
      const response = await ajax(
        `/admin/plugins/discourse-workflows/workflows/${this.args.workflow.id}/variables/${variable.id}.json`,
        { type: "DELETE" }
      );

      this.args.workflow.variables = this.variables.filter(
        (v) => v.id !== variable.id
      );
      this.args.workflow.setProperties({
        versionId: response.workflow.version_id,
        activeVersionId: response.workflow.active_version_id,
        hasUnpublishedChanges: response.workflow.has_unpublished_changes,
      });
    } catch (e) {
      popupAjaxError(e);
    }
  }

  <template>
    {{#if this.variables.length}}
      <table class="d-table workflows-variables-table">
        <thead class="d-table__header">
          <tr class="d-table__row">
            <th class="d-table__header-cell">{{i18n
                "discourse_workflows.workflow_variables.key"
              }}</th>
            <th class="d-table__header-cell">{{i18n
                "discourse_workflows.workflow_variables.type"
              }}</th>
          </tr>
        </thead>
        <tbody class="d-table__body">
          {{#each this.variables as |variable|}}
            <tr class="d-table__row workflows-variables-table__row">
              <td class="d-table__cell --overview">
                <LinkTo
                  class="d-table__overview-link"
                  @model={{variable.id}}
                  @route="adminPlugins.show.discourse-workflows.show.variables.edit"
                >
                  <span class="d-table__overview-name">{{variable.label}}</span>
                </LinkTo>
                <code class="workflows-variable-key">{{variable.key}}</code>
              </td>
              <td class="d-table__cell --detail">
                <div class="d-table__mobile-label">
                  {{i18n "discourse_workflows.workflow_variables.type"}}
                </div>
                <span class="workflows-variables-table__type">
                  {{workflowVariableTypeLabel variable.variable_type}}
                </span>
              </td>
              <td class="d-table__cell --controls">
                <div class="d-table__cell-actions">
                  <DButton
                    class="btn-default btn-small workflows-variables-table__edit"
                    @icon="pencil"
                    @route="adminPlugins.show.discourse-workflows.show.variables.edit"
                    @routeModels={{variable.id}}
                    @title="discourse_workflows.edit"
                  />
                  <DButton
                    class="btn-default btn-small btn-danger workflows-variables-table__delete"
                    @action={{fn this.delete variable}}
                    @icon="trash-can"
                    @title="discourse_workflows.delete"
                  />
                </div>
              </td>
            </tr>
          {{/each}}
        </tbody>
      </table>
      <DButton
        class="btn-default workflows-variables__add"
        @icon="plus"
        @label="discourse_workflows.workflow_variables.add_variable"
        @route="adminPlugins.show.discourse-workflows.show.variables.new"
      />
    {{else}}
      <AdminConfigAreaEmptyList
        @ctaLabel="discourse_workflows.workflow_variables.add_variable"
        @ctaRoute="adminPlugins.show.discourse-workflows.show.variables.new"
        @emptyLabel="discourse_workflows.workflow_variables.no_variables"
      />
    {{/if}}
  </template>
}
