import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import HorizontalOverflowNav from "discourse/components/horizontal-overflow-nav";
import NavItem from "discourse/components/nav-item";
import htmlClass from "discourse/helpers/html-class";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { not } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import WorkflowEditableTitle from "discourse/plugins/discourse-workflows/admin/components/workflows/editable-title";
import Stats from "discourse/plugins/discourse-workflows/admin/components/workflows/stats";

class WorkflowShowPage extends Component {
  @tracked enabled = this.args.controller.model.workflow.enabled || false;

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

  @action
  async toggleEnabled(value) {
    this.enabled = value;
    try {
      await ajax(
        `/admin/plugins/discourse-workflows/workflows/${this.workflow.id}.json`,
        {
          type: "PUT",
          data: { workflow: { name: this.workflow.name, enabled: value } },
        }
      );
      this.workflow.set("enabled", value);
    } catch (e) {
      this.enabled = !value;
      popupAjaxError(e);
    }
  }

  <template>
    {{htmlClass "workflows-page"}}
    <DBreadcrumbsItem @label={{this.workflow.name}} />

    <div class="admin-config-page__main-area">
      <div class="workflows-header">
        <WorkflowEditableTitle
          @value={{this.workflow.name}}
          @onSave={{this.updateName}}
        />

        <Stats @stats={{this.stats}} />
      </div>

      <div class="workflows-show-nav-row">
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

        <div class="workflows-status-toggle">
          <span
            class="workflows-status-toggle__indicator
              {{if this.enabled '--published' '--draft'}}"
          >{{if
              this.enabled
              (i18n "discourse_workflows.enabled")
              (i18n "discourse_workflows.disabled")
            }}</span>
          <DToggleSwitch
            @state={{this.enabled}}
            {{on "click" (fn this.toggleEnabled (not this.enabled))}}
          />
        </div>
      </div>

      {{outlet}}
    </div>
  </template>
}

export default WorkflowShowPage;
