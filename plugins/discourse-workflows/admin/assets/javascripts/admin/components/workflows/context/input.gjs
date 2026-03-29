import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { getNodeColor, getNodeIcons } from "../../../lib/workflows/node-utils";
import resolveNodeFields, { fieldsFromSchema } from "./resolve-node-fields";
import SchemaField from "./schema-field";

function ancestorIcon(type) {
  return getNodeIcons()[type]?.icon;
}

function ancestorIconStyle(type) {
  return trustHTML(`color: ${getNodeColor(type)}`);
}

const ENVIRONMENT_FIELDS = [
  { key: "site_settings", type: "object", id: "$site_settings" },
  { key: "vars", type: "object", id: "$vars" },
  {
    key: "current_user",
    type: "object",
    id: "$current_user",
    children: [
      { key: "id", type: "integer", id: "id" },
      { key: "username", type: "string", id: "username" },
    ],
  },
  { key: "execution", type: "object", id: "$execution" },
];

export default class InputContext extends Component {
  get fields() {
    const nodeTypes = this.args.nodeTypes || [];
    const nodes = this.args.nodes || [];
    const connections = this.args.connections || [];

    return resolvePreviousOutput(this.args.node, nodes, connections, nodeTypes);
  }

  get ancestorNodes() {
    const nodeTypes = this.args.nodeTypes || [];
    const nodes = this.args.nodes || [];
    const connections = this.args.connections || [];

    const allAncestors = resolveAllAncestors(
      this.args.node,
      nodes,
      connections,
      nodeTypes
    );

    return allAncestors.slice(1).map((ancestor) => ({
      name: ancestor.node.name,
      type: ancestor.node.type,
      fields: ancestor.fields.map((field) => ({
        ...field,
        id: `$('${ancestor.node.name}').item.json.${field.key}`,
      })),
    }));
  }

  <template>
    <div class="workflows-context-panel">
      <div class="workflows-context-panel__section">
        <h3 class="workflows-context-panel__title">
          {{icon "right-to-bracket"}}
          {{i18n "discourse_workflows.configurator.input_context"}}
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

      <div class="workflows-context-panel__section">
        <h3 class="workflows-context-panel__title">
          {{icon "gear"}}
          {{i18n "discourse_workflows.configurator.environment"}}
        </h3>

        <ul class="workflows-schema-field-list">
          {{#each ENVIRONMENT_FIELDS as |field|}}
            <SchemaField @field={{field}} @draggable={{true}} />
          {{/each}}
        </ul>
      </div>

      {{#each this.ancestorNodes as |ancestor|}}
        <div class="workflows-context-panel__section">
          <h3 class="workflows-context-panel__title">
            <span style={{ancestorIconStyle ancestor.type}}>
              {{icon (ancestorIcon ancestor.type)}}
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

function findPreviousNode(node, nodes, connections, visited) {
  if (visited.has(node.clientId)) {
    return null;
  }
  visited.add(node.clientId);

  const incoming = connections.find(
    (c) =>
      c.targetClientId === node.clientId &&
      c.sourceClientId !== node.clientId &&
      !visited.has(c.sourceClientId)
  );
  if (!incoming) {
    return null;
  }

  return nodes.find((n) => n.clientId === incoming.sourceClientId) || null;
}

export function resolvePreviousOutput(
  node,
  nodes,
  connections,
  nodeTypes,
  visited = new Set()
) {
  const previousNode = findPreviousNode(node, nodes, connections, visited);
  if (!previousNode) {
    return [];
  }

  if (previousNode.type?.startsWith("trigger:")) {
    const triggerType = nodeTypes.find(
      (nt) => nt.identifier === previousNode.type
    );
    return fieldsFromSchema(triggerType?.output_schema) || [];
  }

  if (previousNode.type?.startsWith("condition:")) {
    return resolvePreviousOutput(
      previousNode,
      nodes,
      connections,
      nodeTypes,
      visited
    );
  }

  const ownFields = resolveNodeFields(previousNode, nodeTypes) || [];
  if (ownFields.length) {
    return ownFields;
  }

  return resolvePreviousOutput(
    previousNode,
    nodes,
    connections,
    nodeTypes,
    visited
  );
}

export function resolveAllAncestors(
  node,
  nodes,
  connections,
  nodeTypes,
  visited = new Set()
) {
  const prevNode = findPreviousNode(node, nodes, connections, visited);
  if (!prevNode) {
    return [];
  }

  const result = [];

  if (prevNode.type?.startsWith("trigger:")) {
    const triggerType = nodeTypes.find((nt) => nt.identifier === prevNode.type);
    const fields = fieldsFromSchema(triggerType?.output_schema);
    if (fields) {
      result.push({ node: prevNode, fields });
    }
  } else if (!prevNode.type?.startsWith("condition:")) {
    const fields = resolveNodeFields(prevNode, nodeTypes);
    if (fields?.length) {
      result.push({ node: prevNode, fields });
    }
  }

  result.push(
    ...resolveAllAncestors(prevNode, nodes, connections, nodeTypes, visited)
  );

  return result;
}
