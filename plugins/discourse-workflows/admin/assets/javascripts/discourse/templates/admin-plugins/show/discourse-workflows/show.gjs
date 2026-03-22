import Component from "@glimmer/component";
import { action } from "@ember/object";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import HorizontalOverflowNav from "discourse/components/horizontal-overflow-nav";
import NavItem from "discourse/components/nav-item";
import htmlClass from "discourse/helpers/html-class";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import WorkflowEditableTitle from "discourse/plugins/discourse-workflows/admin/components/workflows/editable-title";
import Stats from "discourse/plugins/discourse-workflows/admin/components/workflows/stats";

class WorkflowShowPage extends Component {
  get workflow() {
    return this.args.controller.model.workflow;
  }

  get stats() {
    return this.args.controller.model.stats;
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
    <DBreadcrumbsItem @label={{this.workflow.name}} />

    <div class="admin-config-page__main-area">
      <WorkflowEditableTitle
        @value={{this.workflow.name}}
        @onSave={{this.updateName}}
      />

      <Stats @stats={{this.stats}} />

      <HorizontalOverflowNav class="workflows-show-nav">
        <NavItem
          @route="adminPlugins.show.discourse-workflows.show.index"
          @label="discourse_workflows.tabs.workflow"
        />
        <NavItem
          @route="adminPlugins.show.discourse-workflows.show.executions"
          @label="discourse_workflows.tabs.executions"
        />
        <NavItem
          @route="adminPlugins.show.discourse-workflows.show.settings"
          @label="discourse_workflows.tabs.settings"
        />
      </HorizontalOverflowNav>

      {{outlet}}
    </div>
  </template>
}

export default WorkflowShowPage;
