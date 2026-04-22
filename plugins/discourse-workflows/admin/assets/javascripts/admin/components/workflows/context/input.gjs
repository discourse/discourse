import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import processFields from "../../../lib/workflows/field-processors";
import {
  findPreviousNode,
  resolveAllAncestors,
  resolveFieldsForNode,
} from "../../../lib/workflows/graph-traversal";
import { nodeTypeColor, nodeTypeIcon } from "../../../lib/workflows/node-types";
import DragDropHint from "./drag-drop-hint";
import SchemaField from "./schema-field";

function ancestorIconStyle(type) {
  return trustHTML(`color: ${nodeTypeColor(type)}`);
}

function nodeMatchesCondition(node, condition) {
  if (condition.type && node.type !== condition.type) {
    return false;
  }
  if (condition.configuration) {
    for (const [key, value] of Object.entries(condition.configuration)) {
      if (node.configuration?.[key] !== value) {
        return false;
      }
    }
  }
  return true;
}

function fieldVisible(fieldDef, nodes) {
  if (!fieldDef.visible_if?.node_present) {
    return true;
  }
  return (nodes || []).some((n) =>
    nodeMatchesCondition(n, fieldDef.visible_if.node_present)
  );
}

function schemaFieldToEntry(key, def, nodes) {
  const displayKey = key.replace(/^\$/, "");
  const entry = {
    key: displayKey,
    type: def.type || "object",
    id: key,
  };

  if (def.fields) {
    entry.children = Object.entries(def.fields)
      .filter(([, childDef]) => fieldVisible(childDef, nodes))
      .map(([childKey, childDef]) => ({
        key: childKey,
        type: childDef.type || "string",
        id: childKey,
      }));
  }

  return entry;
}

function triggerProvidesCurrentUser(nodes, nodeTypesService) {
  const triggerNode = (nodes || []).find((n) => n.type?.startsWith("trigger:"));
  if (!triggerNode) {
    return false;
  }
  const nodeType = nodeTypesService.findNodeType(triggerNode.type);
  return nodeType?.capabilities?.provides_current_user ?? false;
}

function environmentFields(expressionContext, nodes, nodeTypesService) {
  const env = expressionContext.environment;
  if (!env) {
    return [];
  }

  const hasCurrentUser = triggerProvidesCurrentUser(nodes, nodeTypesService);

  return Object.entries(env)
    .filter(([, def]) => {
      if (def.provided_by_trigger) {
        return hasCurrentUser;
      }
      return true;
    })
    .map(([symbol, def]) => schemaFieldToEntry(symbol, def, nodes));
}

export default class InputContext extends Component {
  @service workflowsNodeTypes;

  get graph() {
    return {
      nodes: this.args.nodes || [],
      connections: this.args.connections || [],
      nodeTypes: this.args.nodeTypes || [],
    };
  }

  @cached
  get previousNode() {
    return findPreviousNode(this.args.node, this.graph, new Set());
  }

  get fields() {
    if (!this.previousNode) {
      return [];
    }
    const fields = resolveFieldsForNode(this.previousNode, this.graph) || [];
    return processFields(fields, this.args.node, this.graph);
  }

  get environmentFields() {
    return environmentFields(
      this.workflowsNodeTypes.expressionContext,
      this.args.nodes || [],
      this.workflowsNodeTypes
    );
  }

  get ancestorNodes() {
    const previous = this.previousNode;
    return resolveAllAncestors(this.args.node, this.graph)
      .filter((ancestor) => ancestor.node !== previous)
      .map((ancestor) => ({
        name: ancestor.node.name,
        type:
          this.workflowsNodeTypes.findNodeType(ancestor.node.type) ||
          ancestor.node.type,
        fields: ancestor.fields.map((field) => ({
          ...field,
          id: `$('${ancestor.node.name}').item.json.${field.key}`,
        })),
      }));
  }

  <template>
    <div class="workflows-context-panel">
      {{#if @hasConfiguration}}
        <DragDropHint />
      {{/if}}

      {{#if this.previousNode}}
        <div class="workflows-context-panel__section">
          <h3 class="workflows-context-panel__title">
            {{icon "right-to-bracket"}}
            {{this.previousNode.name}}
          </h3>

          {{#if this.fields.length}}
            <ul class="workflows-schema-field-list">
              {{#each this.fields as |field|}}
                <SchemaField @field={{field}} @draggable={{true}} />
              {{/each}}
            </ul>
          {{else}}
            <p class="workflows-context-panel__empty">
              {{i18n "discourse_workflows.configurator.no_input_context"}}
            </p>
          {{/if}}
        </div>
      {{/if}}

      <div class="workflows-context-panel__section">
        <h3 class="workflows-context-panel__title">
          {{icon "gear"}}
          {{i18n "discourse_workflows.configurator.environment"}}
        </h3>

        <ul class="workflows-schema-field-list">
          {{#each this.environmentFields as |field|}}
            <SchemaField @field={{field}} @draggable={{true}} />
          {{/each}}
        </ul>
      </div>

      {{#each this.ancestorNodes as |ancestor|}}
        <div class="workflows-context-panel__section">
          <h3 class="workflows-context-panel__title">
            <span style={{ancestorIconStyle ancestor.type}}>
              {{icon (nodeTypeIcon ancestor.type)}}
            </span>
            {{ancestor.name}}
          </h3>

          <ul class="workflows-schema-field-list">
            {{#each ancestor.fields as |field|}}
              <SchemaField @field={{field}} @draggable={{true}} />
            {{/each}}
          </ul>
        </div>
      {{/each}}
    </div>
  </template>
}
