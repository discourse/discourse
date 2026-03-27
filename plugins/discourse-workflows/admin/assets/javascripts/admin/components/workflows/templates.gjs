import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { loadNodeTypes } from "../../lib/workflows/node-types";
import { getNodeIcons } from "../../lib/workflows/node-utils";
import StickyNote from "../../models/sticky-note";

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
  return getNodeIcons()[nodeType]?.icon || "cog";
}

function iconStyle(nodeType) {
  const key = getNodeIcons()[nodeType]?.colorKey;
  const color = key
    ? `var(--workflow-node-color-${key})`
    : "var(--primary-medium)";
  return trustHTML(`color: ${color}`);
}

export default class WorkflowsTemplates extends Component {
  @service router;

  @tracked creatingTemplateId = null;
  @tracked nodeTypesLoaded = false;

  @action
  async ensureNodeTypes() {
    await loadNodeTypes();
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

      const nodes = fullTemplate.template.nodes.map((n, index) => ({
        client_id: `template-${index}`,
        type: n.type,
        type_version: n.type_version,
        name: n.name,
        configuration: n.configuration || {},
        position: n.position || null,
      }));

      const connections = (fullTemplate.template.connections || []).map(
        (c) => ({
          source_client_id: `template-${c.source_index}`,
          target_client_id: `template-${c.target_index}`,
          source_output: c.source_output || "main",
        })
      );

      const stickyNotes = (fullTemplate.template.sticky_notes || []).map((n) =>
        StickyNote.serialize(StickyNote.create(n))
      );

      const workflow = {
        name: fullTemplate.template.name,
        nodes,
        connections,
      };
      if (stickyNotes.length > 0) {
        workflow.sticky_notes = stickyNotes;
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
              {{#each (visibleNodeTypes tmpl.node_types) as |nodeType|}}
                <span
                  class="workflows-templates__icon"
                  style={{iconStyle nodeType}}
                >
                  {{icon (iconFor nodeType)}}
                </span>
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
