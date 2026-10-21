import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class ManagedWorkflowView extends Component {
  @service router;

  @tracked duplicating = false;

  get nodes() {
    return this.args.workflow.nodes.map((node) => ({
      id: node.id || node.clientId,
      name: node.name,
      type: node.type,
      icon: node.type.startsWith("trigger:") ? "bolt" : "globe",
      parameters: JSON.stringify(
        node.parameters || node.configuration || {},
        null,
        2
      ),
    }));
  }

  @action
  async duplicate() {
    this.duplicating = true;
    try {
      const result = await ajax(
        `/admin/plugins/discourse-workflows/workflows/${this.args.workflow.id}/duplicate.json`,
        { type: "POST" }
      );
      this.router.transitionTo(
        "adminPlugins.show.discourse-workflows.show",
        result.workflow.id
      );
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.duplicating = false;
    }
  }

  <template>
    <section class="managed-workflow-view" ...attributes>
      <div class="managed-workflow-view__ownership">
        <div>
          <h3>{{dIcon "lock"}}
            {{i18n
              "discourse_workflows.managed.title"
              name=@workflow.managed_by.name
            }}</h3>
          <p>{{i18n "discourse_workflows.managed.description"}}</p>
          <span class="managed-workflow-view__published">{{i18n
              "discourse_workflows.published"
            }}</span>
          <p
            class="managed-workflow-view__configuration"
          >{{@workflow.managed_by.configuration_name}}</p>
        </div>
        <div class="managed-workflow-view__actions">
          <DButton
            class="btn-primary"
            @href={{@workflow.managed_by.url}}
            @label="discourse_workflows.managed.configure"
          />
          <DButton
            class="btn-default"
            data-test-duplicate-managed-workflow
            @action={{this.duplicate}}
            @disabled={{this.duplicating}}
            @label="discourse_workflows.managed.duplicate"
          />
        </div>
      </div>
      <div
        aria-label={{i18n "discourse_workflows.managed.steps"}}
        class="managed-workflow-view__graph"
        role="list"
      >
        {{#each this.nodes as |node index|}}
          {{#if index}}<span class="managed-workflow-view__arrow">{{dIcon
                "arrow-right"
              }}</span>{{/if}}
          <article
            class="managed-workflow-view__node"
            data-test-managed-node={{node.type}}
            role="listitem"
          >
            <div class="managed-workflow-view__node-heading">{{dIcon
                node.icon
              }}<h4>{{node.name}}</h4></div>
            <code>{{node.type}}</code>
            <details class="managed-workflow-view__parameters"><summary>{{i18n
                  "discourse_workflows.managed.parameters"
                }}</summary><pre>{{node.parameters}}</pre></details>
          </article>
        {{/each}}
      </div>
    </section>
  </template>
}
