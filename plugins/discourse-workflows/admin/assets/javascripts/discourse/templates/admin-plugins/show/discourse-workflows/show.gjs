import Component from "@glimmer/component";
import { action } from "@ember/object";
import htmlClass from "discourse/helpers/html-class";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DHorizontalOverflowNav from "discourse/ui-kit/d-horizontal-overflow-nav";
import DNavItem from "discourse/ui-kit/d-nav-item";
import WorkflowEditableTitle from "discourse/plugins/discourse-workflows/admin/components/workflows/editable-title";
import Stats from "discourse/plugins/discourse-workflows/admin/components/workflows/stats";
import WorkflowTagsEditor from "discourse/plugins/discourse-workflows/admin/components/workflows/tags-editor";
import { workflowUrl } from "discourse/plugins/discourse-workflows/admin/lib/workflows/urls";

class WorkflowShowPage extends Component {
  get workflow() {
    return this.args.controller.model.workflow;
  }

  get stats() {
    return this.args.controller.model.stats;
  }

  get workflowPath() {
    return workflowUrl(this.workflow.id);
  }

  @action
  async updateName(name) {
    try {
      await ajax(
        `/admin/plugins/discourse-workflows/workflows/${this.workflow.id}.json`,
        { type: "PUT", data: { workflow: { name } } }
      );
      this.workflow.set("name", name);
    } catch (e) {
      popupAjaxError(e);
    }
  }

  <template>
    {{htmlClass "workflows-page"}}
    <DBreadcrumbsItem
      @label={{this.workflow.name}}
      @path={{this.workflowPath}}
    />

    <div class="admin-config-page__main-area">
      <div class="workflows-header">
        <div class="workflows-header__title-area">
          <WorkflowEditableTitle
            @onSave={{this.updateName}}
            @value={{this.workflow.name}}
          />

          <WorkflowTagsEditor @workflow={{this.workflow}} />
        </div>

        <Stats @stats={{this.stats}} />
      </div>

      <div class="workflows-show-nav">
        <DHorizontalOverflowNav>
          <DNavItem
            @currentWhen="adminPlugins.show.discourse-workflows.show.index adminPlugins.show.discourse-workflows.show.node"
            @label="discourse_workflows.tabs.workflow"
            @route="adminPlugins.show.discourse-workflows.show.index"
          />
          <DNavItem
            @label="discourse_workflows.tabs.executions"
            @route="adminPlugins.show.discourse-workflows.show.executions"
          />
          <DNavItem
            @label="discourse_workflows.tabs.settings"
            @route="adminPlugins.show.discourse-workflows.show.settings"
          />
          <DNavItem
            @label="discourse_workflows.tabs.versions"
            @route="adminPlugins.show.discourse-workflows.show.versions"
          />
        </DHorizontalOverflowNav>

      </div>

      {{outlet}}
    </div>
  </template>
}

export default WorkflowShowPage;
