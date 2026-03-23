import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { i18n } from "discourse-i18n";
import AddNodeButton from "./add-button";
import NodeCard from "./card";

export default class NodeStack extends Component {
  get startNode() {
    if (this.args.startClientId) {
      return this.args.nodes.find(
        (n) => n.clientId === this.args.startClientId
      );
    }
    return this.args.nodes.find((n) => n.type?.startsWith("trigger:"));
  }

  get renderChain() {
    const chain = [];
    const visited = new Set();
    let current = this.startNode;

    while (current) {
      if (visited.has(current.clientId)) {
        break;
      }
      visited.add(current.clientId);

      const node = current;
      const outgoing = (this.args.connections || []).filter(
        (c) => c.sourceClientId === node.clientId
      );

      if (node.type === "condition:if") {
        const trueBranch = outgoing.find((c) => c.sourceOutput === "true");
        const falseBranch = outgoing.find((c) => c.sourceOutput === "false");

        chain.push({
          node,
          isCondition: true,
          trueStartClientId: trueBranch?.targetClientId,
          falseStartClientId: falseBranch?.targetClientId,
        });
        break;
      }

      const mainConn = outgoing.find((c) => c.sourceOutput === "main");

      current = mainConn
        ? this.args.nodes.find((n) => n.clientId === mainConn.targetClientId)
        : null;

      chain.push({
        node,
        isCondition: false,
        sourceClientId: node.clientId,
        sourceOutput: "main",
        hasNext: !!current,
      });
    }

    return chain;
  }

  get isEmpty() {
    return !this.startNode;
  }

  <template>
    <div class="workflows-node-stack">
      {{#if this.isEmpty}}
        <AddNodeButton
          @onAddNode={{@onAddNode}}
          @sourceClientId={{null}}
          @sourceOutput="main"
        />
      {{else}}
        {{#each this.renderChain as |entry|}}
          <NodeCard
            @node={{entry.node}}
            @nodes={{@nodes}}
            @connections={{@connections}}
            @workflowId={{@workflowId}}
            @onRemove={{fn @onRemoveNode entry.node.clientId}}
            @onUpdateConfiguration={{fn
              @onUpdateNodeConfiguration
              entry.node.clientId
            }}
            @onReplaceTrigger={{fn @onReplaceTrigger entry.node.clientId}}
          />

          {{#if entry.isCondition}}
            <div class="workflows-node-stack__connector"></div>
            <div class="workflows-node-stack__branches">
              <div class="workflows-node-stack__branch">
                <span class="workflows-node-stack__branch-label">
                  {{i18n "discourse_workflows.branch.true"}}
                </span>
                {{#if entry.trueStartClientId}}
                  <div class="workflows-node-stack__connector"></div>
                  <NodeStack
                    @nodes={{@nodes}}
                    @connections={{@connections}}
                    @workflowId={{@workflowId}}
                    @startClientId={{entry.trueStartClientId}}
                    @onAddNode={{@onAddNode}}
                    @onRemoveNode={{@onRemoveNode}}
                    @onUpdateNodeConfiguration={{@onUpdateNodeConfiguration}}
                    @onReplaceTrigger={{@onReplaceTrigger}}
                  />
                {{else}}
                  <div class="workflows-node-stack__connector"></div>
                  <AddNodeButton
                    @onAddNode={{@onAddNode}}
                    @sourceClientId={{entry.node.clientId}}
                    @sourceOutput="true"
                  />
                {{/if}}
              </div>
              <div class="workflows-node-stack__branch">
                <span class="workflows-node-stack__branch-label">
                  {{i18n "discourse_workflows.branch.false"}}
                </span>
                {{#if entry.falseStartClientId}}
                  <div class="workflows-node-stack__connector"></div>
                  <NodeStack
                    @nodes={{@nodes}}
                    @connections={{@connections}}
                    @workflowId={{@workflowId}}
                    @startClientId={{entry.falseStartClientId}}
                    @onAddNode={{@onAddNode}}
                    @onRemoveNode={{@onRemoveNode}}
                    @onUpdateNodeConfiguration={{@onUpdateNodeConfiguration}}
                    @onReplaceTrigger={{@onReplaceTrigger}}
                  />
                {{else}}
                  <div class="workflows-node-stack__connector"></div>
                  <AddNodeButton
                    @onAddNode={{@onAddNode}}
                    @sourceClientId={{entry.node.clientId}}
                    @sourceOutput="false"
                  />
                {{/if}}
              </div>
            </div>
          {{else}}
            <div class="workflows-node-stack__connector"></div>
            <AddNodeButton
              @onAddNode={{@onAddNode}}
              @sourceClientId={{entry.sourceClientId}}
              @sourceOutput={{entry.sourceOutput}}
            />
            {{#if entry.hasNext}}
              <div class="workflows-node-stack__connector"></div>
            {{/if}}
          {{/if}}
        {{/each}}

      {{/if}}
    </div>
  </template>
}
