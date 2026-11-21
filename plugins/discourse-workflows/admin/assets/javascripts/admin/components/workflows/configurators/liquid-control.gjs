import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import CodeEditor from "discourse/components/code-editor";
import { loadCodeEditorLanguage } from "discourse/lib/code-editor-languages";
import { escapeExpression } from "discourse/lib/utilities";
import { schemaFieldsForNodeInput } from "../../../lib/workflows/data-preview.js";
import {
  inputFieldPrefixForConnection,
  inputIndexForConnection,
  outputIndexForConnection,
} from "../../../lib/workflows/expression-paths.js";
import buildLiquidExtensions from "../../../lib/workflows/liquid-extensions/index.js";
import {
  nodeTypeCapabilities,
  typeVersionForNode,
} from "../../../lib/workflows/node-types.js";
import {
  inputConnectionsForNode,
  previousNodeForConnection,
  resolveDeclaredOutputSchemas,
} from "../../../lib/workflows/schema-graph.js";

export default class LiquidControl extends Component {
  @service siteSettings;
  @service workflowsNodeTypes;

  @tracked ready = false;

  get height() {
    return this.args.schema?.control_options?.height;
  }

  get style() {
    if (!this.height) {
      return;
    }

    return trustHTML(`height: ${escapeExpression(this.height)}px`);
  }

  get value() {
    return this.args.field.value ?? "";
  }

  get #perItem() {
    const node = this.args.node;
    const runScope = nodeTypeCapabilities(
      node?.type,
      typeVersionForNode(node)
    ).run_scope;
    if (!runScope?.parameter) {
      return false;
    }

    // The form's live value, so switching mode takes effect before saving.
    const mode =
      this.args.formApi?.get(runScope.parameter) ??
      (this.args.nodeParameters || this.args.configuration)?.[
        runScope.parameter
      ];

    return runScope.values?.[mode] === "per_item";
  }

  @action
  async load() {
    // Grammar first, so delimiter rules apply from the first keystroke.
    await Promise.all([
      this.workflowsNodeTypes.loadWorkflowVars(),
      loadCodeEditorLanguage("liquid"),
    ]);
    if (!this.isDestroying) {
      this.ready = true;
    }
  }

  @action
  buildExtensions(cmParams) {
    const session = this.args.session;
    const node = this.args.node;
    const graph = {
      nodes: session?.graphNodes || [],
      connections: session?.graphConnections || [],
      nodeTypes: this.workflowsNodeTypes.nodeTypes || [],
    };
    const runData = session?.lastExecutionRunData || {};
    const declaredOutputSchemas = resolveDeclaredOutputSchemas(graph);
    const connections = node ? inputConnectionsForNode(node, graph) : [];

    const branchFields = [];
    const secondaryInputs = [];
    const primaryConnection = connections[0] || null;
    for (const connection of connections) {
      const inputIndex = inputIndexForConnection(connection);
      branchFields[inputIndex] = this.#fieldsForConnection(connection, {
        node,
        graph,
        runData,
        declaredOutputSchemas,
        session,
      });
      if (connection !== primaryConnection) {
        secondaryInputs.push({
          inputIndex,
          prefix: inputFieldPrefixForConnection(
            connection,
            previousNodeForConnection(connection, graph),
            { primaryConnection }
          ),
        });
      }
    }

    return buildLiquidExtensions(cmParams, {
      branchFields,
      secondaryInputs,
      siteSettings: this.siteSettings,
      globalVars: this.workflowsNodeTypes.workflowVars,
      perItem: () => this.#perItem,
    });
  }

  @action
  handleChange(value) {
    this.args.field.set(value);
  }

  #fieldsForConnection(
    connection,
    { node, graph, runData, declaredOutputSchemas, session }
  ) {
    const sourceNode = previousNodeForConnection(connection, graph);
    const outputIndex = outputIndexForConnection(connection);

    return schemaFieldsForNodeInput(runData, node.name, {
      inputIndex: inputIndexForConnection(connection),
      node,
      sourceNode,
      outputIndex,
      graph,
      declaredOutputSchemas,
      pinnedItems:
        outputIndex === 0
          ? session?.pinnedItemsForNode(sourceNode?.name)
          : undefined,
    });
  }

  <template>
    <div class="workflows-liquid-control" {{didInsert this.load}}>
      {{#if this.ready}}
        <CodeEditor
          class="form-kit__control-code workflows-liquid-control__editor"
          name={{@field.name}}
          style={{this.style}}
          @describedBy={{@field.describedBy}}
          @disabled={{@field.disabled}}
          @extensions={{this.buildExtensions}}
          @inputId={{@field.id}}
          @invalid={{if @field.error true false}}
          @language="liquid"
          @lineWrapping={{true}}
          @onChange={{this.handleChange}}
          @resizable={{true}}
          @value={{this.value}}
        />
      {{/if}}
    </div>
  </template>
}
