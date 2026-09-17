import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import CodeEditor from "discourse/components/code-editor";
import { escapeExpression } from "discourse/lib/utilities";
import { schemaFieldsForNodeInput } from "../../../lib/workflows/data-preview";
import {
  inputIndexForConnection,
  outputIndexForConnection,
} from "../../../lib/workflows/expression-paths";
import buildLiquidExtensions from "../../../lib/workflows/liquid-extensions";
import {
  inputConnectionsForNode,
  previousNodeForConnection,
  resolveDeclaredOutputSchemas,
} from "../../../lib/workflows/schema-graph";

const MODE_FIELD = "mode";
const PER_ITEM_MODE = "runOnceForEachItem";

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
    // The form's live value, so switching mode takes effect before the node is
    // saved; the stored parameters cover the first render.
    const mode =
      this.args.formApi?.get(MODE_FIELD) ??
      (this.args.nodeParameters || this.args.configuration)?.[MODE_FIELD];

    return mode === PER_ITEM_MODE;
  }

  @action
  async loadVariables() {
    await this.workflowsNodeTypes.loadWorkflowVars();
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
    for (const connection of connections) {
      branchFields[inputIndexForConnection(connection)] =
        this.#fieldsForConnection(connection, {
          node,
          graph,
          runData,
          declaredOutputSchemas,
          session,
        });
    }

    return buildLiquidExtensions(cmParams, {
      inputFields: branchFields[0] || [],
      branchFields,
      siteSettings: this.siteSettings,
      workflowVars: this.workflowsNodeTypes.workflowVars,
      nodes: graph.nodes,
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
      // Pinned sample data, falling back to the last run.
      pinnedItems:
        outputIndex === 0
          ? session?.pinnedItemsForNode(sourceNode?.name)
          : undefined,
    });
  }

  <template>
    <div class="workflows-liquid-control" {{didInsert this.loadVariables}}>
      {{#if this.ready}}
        <CodeEditor
          class="workflows-variable-input --liquid"
          name={{@field.name}}
          style={{this.style}}
          @describedBy={{@field.describedBy}}
          @disabled={{@field.disabled}}
          @extensions={{this.buildExtensions}}
          @inputId={{@field.id}}
          @invalid={{@field.error}}
          @lineWrapping={{true}}
          @onChange={{this.handleChange}}
          @resizable={{true}}
          @value={{this.value}}
        />
      {{/if}}
    </div>
  </template>
}
