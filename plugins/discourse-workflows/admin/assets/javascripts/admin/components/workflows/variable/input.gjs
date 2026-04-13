import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import loadCodemirrorEditor from "discourse/lib/load-codemirror";
import buildWorkflowExtension from "../../../lib/workflows/codemirror-extension";
import {
  resolveAllAncestors,
  resolvePreviousOutput,
} from "../../../lib/workflows/graph-traversal";

export default class VariableInput extends Component {
  @service siteSettings;
  @service workflowsNodeTypes;

  @tracked Editor;

  get #graph() {
    return {
      nodes: this.workflowsNodeTypes.graphNodes || [],
      connections: this.workflowsNodeTypes.graphConnections || [],
      nodeTypes: this.workflowsNodeTypes.nodeTypes || [],
    };
  }

  get #node() {
    return this.workflowsNodeTypes.editingNode;
  }

  get #itemPrefix() {
    return this.workflowsNodeTypes.expressionContext.item_prefix || "$json";
  }

  get extension() {
    const node = this.#node;
    const graph = this.#graph;
    const domainOpts = {
      inputFields: node ? resolvePreviousOutput(node, graph) : [],
      ancestorNodes: node ? resolveAllAncestors(node, graph) : [],
      siteSettings: this.siteSettings,
      workflowVars: this.workflowsNodeTypes.workflowVars,
      nodes: graph.nodes,
      itemPrefix: this.#itemPrefix,
    };
    return (cmParams) => buildWorkflowExtension(cmParams, domainOpts);
  }

  @action
  async loadEditor() {
    const [Editor] = await Promise.all([
      loadCodemirrorEditor(),
      this.workflowsNodeTypes.loadWorkflowVars(),
    ]);

    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    this.Editor = Editor;
  }

  @action
  handleSetup(view, extensionResult) {
    this.args.onEditorReady?.({
      view,
      markInvalidExpressions: extensionResult?.markInvalidExpressions,
      clearInvalidExpressions: extensionResult?.clearInvalidExpressions,
    });
  }

  @action
  handleChange(value) {
    this.args.onChange?.(value);
  }

  <template>
    <div
      class="workflows-variable-input-container"
      {{didInsert this.loadEditor}}
    >
      {{#if this.Editor}}
        <this.Editor
          @value={{@value}}
          @change={{this.handleChange}}
          @extension={{this.extension}}
          @class="workflows-variable-input"
          @lineWrapping={{true}}
          @onSetup={{this.handleSetup}}
          @focusIn={{@onFocusIn}}
          @focusOut={{@onFocusOut}}
        />
      {{/if}}
    </div>
  </template>
}
