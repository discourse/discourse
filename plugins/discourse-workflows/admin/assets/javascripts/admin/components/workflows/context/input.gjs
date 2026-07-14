import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import {
  ancestorOutputNodes,
  inputConnectionsForNode,
  inputFieldPrefixForConnection,
  inputIndexForConnection,
  inputSummaryForNode,
  nodeOutputJsonPath,
  outputIndexForConnection,
  outputSummaryForNode,
  previousNodeForConnection,
  schemaFieldsForNodeInput,
  schemaFieldsForNodeOutput,
} from "../../../lib/workflows/data-schema";
import processFields from "../../../lib/workflows/field-processors";
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
  if (condition.parameters) {
    for (const [key, value] of Object.entries(condition.parameters)) {
      if (node.configuration?.[key] !== value) {
        return false;
      }
    }
  }
  return true;
}

function fieldVisible(fieldDef, nodes) {
  const nodePresentConditions = fieldDef.display_options?.show?.node_present;
  if (!nodePresentConditions) {
    return true;
  }
  return nodePresentConditions.some((condition) =>
    (nodes || []).some((n) => nodeMatchesCondition(n, condition))
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
  get inputConnections() {
    return inputConnectionsForNode(this.args.node, this.graph);
  }

  get primaryInputConnection() {
    return this.inputConnections[0] || null;
  }

  get runData() {
    return this.args.session?.lastExecutionRunData || {};
  }

  itemCountLabel(summary) {
    if (!summary?.itemCount) {
      return null;
    }

    return i18n("discourse_workflows.configurator.schema_item_count", {
      count: summary.itemCount,
    });
  }

  emptyMessage(summary) {
    if (summary?.itemCount > 0) {
      return i18n("discourse_workflows.configurator.no_input_fields");
    }

    return i18n("discourse_workflows.configurator.no_input_context");
  }

  get inputSections() {
    return this.inputConnections
      .map((connection) => {
        const previousNode = previousNodeForConnection(connection, this.graph);
        if (!previousNode) {
          return null;
        }

        const inputIndex = inputIndexForConnection(connection);
        const outputIndex = outputIndexForConnection(connection);
        const recordedInputSummary = inputSummaryForNode(
          this.runData,
          this.args.node.name,
          inputIndex,
          {
            node: this.args.node,
            sourceNode: previousNode,
            outputIndex,
          }
        );
        const fields = schemaFieldsForNodeInput(
          this.runData,
          this.args.node.name,
          {
            inputIndex,
            node: this.args.node,
            sourceNode: previousNode,
            outputIndex,
            prefix: inputFieldPrefixForConnection(connection, previousNode, {
              primaryConnection: this.primaryInputConnection,
            }),
          }
        );

        return {
          node: previousNode,
          inputIndex,
          fields: processFields(fields, this.args.node, this.graph),
          itemCountLabel: this.itemCountLabel(recordedInputSummary),
          inputLabel: this.inputConnectionLabel(inputIndex),
          emptyMessage: this.emptyMessage(recordedInputSummary),
        };
      })
      .filter(Boolean);
  }

  inputConnectionLabel(inputIndex) {
    if (this.inputConnections.length < 2 && inputIndex === 0) {
      return null;
    }

    return i18n("discourse_workflows.configurator.schema_input_label", {
      number: inputIndex + 1,
    });
  }

  get environmentFields() {
    return environmentFields(
      this.workflowsNodeTypes.expressionContext,
      this.args.nodes || [],
      this.workflowsNodeTypes
    );
  }

  get ancestorNodes() {
    const directNodeIds = new Set(
      this.inputSections.map((section) => section.node.clientId)
    );

    return ancestorOutputNodes(this.args.node, this.graph)
      .filter((ancestor) => !directNodeIds.has(ancestor.node.clientId))
      .map((ancestor) => {
        const fields = schemaFieldsForNodeOutput(
          this.runData,
          ancestor.node.name,
          {
            outputIndex: ancestor.outputIndex,
            node: ancestor.node,
            prefix: nodeOutputJsonPath(this.runData, ancestor.node.name, {
              outputIndex: ancestor.outputIndex,
              node: ancestor.node,
            }),
          }
        );
        return {
          name: ancestor.node.name,
          type:
            this.workflowsNodeTypes.findNodeType(ancestor.node.type) ||
            ancestor.node.type,
          fields,
          itemCountLabel: this.itemCountLabel(
            outputSummaryForNode(
              this.runData,
              ancestor.node.name,
              ancestor.outputIndex,
              { node: ancestor.node }
            )
          ),
        };
      })
      .filter((ancestor) => ancestor.fields.length);
  }

  <template>
    <div class="workflows-context-panel">
      {{#if @hasConfiguration}}
        <DragDropHint />
      {{/if}}

      {{#each this.inputSections as |section|}}
        <div class="workflows-context-panel__section">
          <h3 class="workflows-context-panel__title">
            {{dIcon "right-to-bracket"}}
            {{section.node.name}}
            {{#if section.inputLabel}}
              <span class="workflows-context-panel__title-info">
                {{section.inputLabel}}
              </span>
            {{/if}}
            {{#if section.itemCountLabel}}
              <span class="workflows-context-panel__title-meta">
                {{section.itemCountLabel}}
              </span>
            {{/if}}
          </h3>

          {{#if section.fields.length}}
            <ul class="workflows-schema-field-list">
              {{#each section.fields as |field|}}
                <SchemaField @field={{field}} @draggable={{true}} />
              {{/each}}
            </ul>
          {{else}}
            <p class="workflows-context-panel__empty">
              {{section.emptyMessage}}
            </p>
          {{/if}}
        </div>
      {{/each}}

      <div class="workflows-context-panel__section">
        <h3 class="workflows-context-panel__title">
          {{dIcon "gear"}}
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
              {{dIcon (nodeTypeIcon ancestor.type)}}
            </span>
            {{ancestor.name}}
            {{#if ancestor.itemCountLabel}}
              <span class="workflows-context-panel__title-meta">
                {{ancestor.itemCountLabel}}
              </span>
            {{/if}}
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
