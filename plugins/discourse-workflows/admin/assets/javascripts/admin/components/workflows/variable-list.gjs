import Component from "@glimmer/component";
import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import DButton from "discourse/ui-kit/d-button";

export default class WorkflowVariableList extends Component {
  get variables() {
    return this.args.workflow.variables;
  }

  <template>
    {{#if this.variables.length}}
      <DButton
        class="btn-default workflows-variables__manage"
        @icon="list"
        @label="discourse_workflows.workflow_variables.manage_variables"
        @route="adminPlugins.show.discourse-workflows.show.variables.manage"
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
