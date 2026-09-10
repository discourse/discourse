import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
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
import VariableInput from "../variable/input";

const MODE_FIELD = "mode";
const PER_ITEM_MODE = "runOnceForEachItem";

export default class LiquidControl extends Component {
  @service siteSettings;
  @service workflowsNodeTypes;

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

    // `inputs` is indexed by connection order, so every branch is resolved,
    // while `items` follows the first one.
    const branchFields = connections.map((connection) =>
      this.#fieldsForConnection(connection, {
        node,
        graph,
        runData,
        declaredOutputSchemas,
        session,
      })
    );

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
    <div class="workflows-liquid-control" style={{this.style}}>
      <VariableInput
        @class="--liquid"
        @extensions={{this.buildExtensions}}
        @lineNumbers={{true}}
        @onChange={{this.handleChange}}
        @value={{this.value}}
      />
    </div>
  </template>
}
