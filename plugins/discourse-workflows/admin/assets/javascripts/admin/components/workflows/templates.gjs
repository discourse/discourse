import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { nodeTypeColor, nodeTypeIcon } from "../../lib/workflows/node-types";
import { workflowFromTemplate } from "../../lib/workflows/template-workflow";

const MAX_VISIBLE_ICONS = 3;

function visibleNodeTypes(nodeTypes) {
  return (nodeTypes || []).slice(0, MAX_VISIBLE_ICONS);
}

function hasOverflow(nodeTypes) {
  return (nodeTypes || []).length > MAX_VISIBLE_ICONS;
}

function overflowCount(nodeTypes) {
  return (nodeTypes || []).length - MAX_VISIBLE_ICONS;
}

function iconFor(nodeType) {
  return nodeTypeIcon(nodeType) || "cog";
}

function iconStyle(nodeType) {
  return trustHTML(`color: ${nodeTypeColor(nodeType)}`);
}

export default class WorkflowsTemplates extends Component {
  @service router;
  @service workflowsNodeTypes;

  @tracked creatingTemplateId = null;
  @tracked nodeTypesLoaded = false;

  resolveNodeType = (identifier) => {
    return this.workflowsNodeTypes.findNodeType(identifier) || identifier;
  };

  get workflowId() {
    return this.router.currentRoute?.queryParams?.workflow_id;
  }

  @action
  async ensureNodeTypes() {
    await this.workflowsNodeTypes.load();
    this.nodeTypesLoaded = true;
  }

  @action
  async useTemplate(template) {
    if (this.creatingTemplateId) {
      return;
    }

    this.creatingTemplateId = template.id;

    try {
      const fullTemplate = await ajax(
        `/admin/plugins/discourse-workflows/templates/${template.id}.json`
      );

      const workflow = workflowFromTemplate(fullTemplate.template);

      if (this.workflowId) {
        await ajax(
          `/admin/plugins/discourse-workflows/workflows/${this.workflowId}.json`,
          {
            type: "PUT",
            contentType: "application/json",
            data: JSON.stringify({ workflow }),
          }
        );

        this.router.transitionTo(
          "adminPlugins.show.discourse-workflows.show",
          this.workflowId
        );
        return;
      }

      const result = await ajax(
        "/admin/plugins/discourse-workflows/workflows.json",
        {
          type: "POST",
          contentType: "application/json",
          data: JSON.stringify({ workflow }),
        }
      );

      this.router.transitionTo(
        "adminPlugins.show.discourse-workflows.show",
        result.workflow.id
      );
    } catch (e) {
      popupAjaxError(e);
      this.creatingTemplateId = null;
    }
  }

  <template>
    <div class="workflows-templates" {{didInsert this.ensureNodeTypes}}>
      {{#each @templates as |tmpl|}}
        <button
          type="button"
          class="workflows-templates__tile"
          disabled={{this.creatingTemplateId}}
          {{on "click" (fn this.useTemplate tmpl)}}
        >
          <span class="workflows-templates__description">
            {{tmpl.description}}
          </span>
          {{#if this.nodeTypesLoaded}}
            <div class="workflows-templates__icons">
              {{#each (visibleNodeTypes tmpl.node_types) as |nodeTypeId|}}
                {{#let (this.resolveNodeType nodeTypeId) as |nodeType|}}
                  <span
                    class="workflows-templates__icon"
                    style={{iconStyle nodeType}}
                  >
                    {{dIcon (iconFor nodeType)}}
                  </span>
                {{/let}}
              {{/each}}
              {{#if (hasOverflow tmpl.node_types)}}
                <span class="workflows-templates__icon --overflow">
                  +{{overflowCount tmpl.node_types}}
                </span>
              {{/if}}
            </div>
          {{/if}}
        </button>
      {{/each}}
    </div>
  </template>
}
