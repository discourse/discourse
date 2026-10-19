import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { trustHTML } from "@ember/template";
import { bind } from "discourse/lib/decorators";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import {
  extractWorkflowPreview,
  layoutWorkflowPreview,
} from "../../lib/admin-assistant/workflow-preview.js";

function nodeIcon(type) {
  if (type.startsWith("trigger:")) {
    return "bolt";
  }
  if (type.includes("condition") || type.includes("branch")) {
    return "code-branch";
  }
  return "gear";
}

function connectionLabel(connection) {
  if (connection.connectionType && connection.connectionType !== "main") {
    return connection.connectionType;
  }
  if (connection.branchNumber) {
    return i18n("discourse_workflows.admin_assistant.preview.branch", {
      number: connection.branchNumber,
    });
  }
  return null;
}

export default class AdminAssistantWorkflowPreview extends Component {
  @cached
  get preview() {
    const hasConfirmation = this.args.message?.blocks?.some(
      (block) => block.type === "confirmation"
    );
    if (!hasConfirmation) {
      return null;
    }

    return extractWorkflowPreview(this.args.message?.cooked);
  }

  @cached
  get layout() {
    return this.preview?.nodes ? layoutWorkflowPreview(this.preview) : null;
  }

  get hasFailedScripts() {
    const validations = this.preview?.configuration?.script_validations;
    return (
      Array.isArray(validations) &&
      validations.some((validation) => validation?.valid === false)
    );
  }

  get exactConfiguration() {
    return JSON.stringify(this.preview.configuration, null, 2);
  }

  get markerId() {
    return `assistant-workflow-preview-arrow-${this.args.message?.id ?? "draft"}`;
  }

  get markerUrl() {
    return `url(#${this.markerId})`;
  }

  get viewportStyle() {
    return trustHTML(
      `width: ${this.layout.width}px; height: ${this.layout.height}px;`
    );
  }

  @bind
  nodeConnections(node) {
    return this.layout.connections
      .filter((connection) => connection.from === node.id)
      .map((connection) => {
        const target = this.preview.nodes.find(
          (candidate) => candidate.id === connection.to
        );
        if (!target) {
          return null;
        }

        return connectionLabel(connection)
          ? `${connectionLabel(connection)}: ${target.name}`
          : target.name;
      })
      .filter(Boolean)
      .join(", ");
  }

  @bind
  nodeStyle(node) {
    return trustHTML(
      `left: ${node.x}px; top: ${node.y}px; width: ${this.layout.nodeWidth}px; height: ${this.layout.nodeHeight}px;`
    );
  }

  <template>
    {{#if this.preview}}
      <section
        aria-label={{i18n "discourse_workflows.admin_assistant.preview.label"}}
        class="assistant-workflow-preview"
      >
        <header class="assistant-workflow-preview__header">
          <span class="assistant-workflow-preview__heading">
            {{dIcon "code-branch"}}
            <span>{{this.preview.name}}</span>
          </span>
          <span class="assistant-workflow-preview__badge">
            {{i18n "discourse_workflows.admin_assistant.preview.read_only"}}
          </span>
        </header>

        {{#if this.hasFailedScripts}}
          <p class="assistant-workflow-preview__warning" role="status">
            {{i18n
              "discourse_workflows.admin_assistant.preview.script_validation_warning"
            }}
          </p>
        {{/if}}

        {{#if this.layout}}
          <div class="assistant-workflow-preview__scroller" tabindex="0">
            <div
              class="assistant-workflow-preview__viewport"
              style={{this.viewportStyle}}
            >
              <svg
                aria-hidden="true"
                class="assistant-workflow-preview__connections"
                height={{this.layout.height}}
                viewBox="0 0 {{this.layout.width}} {{this.layout.height}}"
                width={{this.layout.width}}
              >
                <defs>
                  <marker
                    id={{this.markerId}}
                    markerHeight="7"
                    markerWidth="7"
                    orient="auto"
                    refX="6"
                    refY="3.5"
                  >
                    <path d="M 0 0 L 7 3.5 L 0 7 z" />
                  </marker>
                </defs>
                {{#each this.layout.connections as |connection|}}
                  <path
                    class="assistant-workflow-preview__connection"
                    d={{connection.path}}
                    marker-end={{this.markerUrl}}
                  />
                  {{#if (connectionLabel connection)}}
                    <text
                      class="assistant-workflow-preview__connection-label"
                      data-connection-type={{connection.connectionType}}
                      data-output-index={{connection.outputIndex}}
                      x={{connection.labelX}}
                      y={{connection.labelY}}
                    >{{connectionLabel connection}}</text>
                  {{/if}}
                {{/each}}
              </svg>

              {{#each this.layout.nodes as |node|}}
                <article
                  class="assistant-workflow-preview__node"
                  data-node-type={{node.type}}
                  style={{this.nodeStyle node}}
                >
                  <span class="assistant-workflow-preview__node-icon">
                    {{dIcon (nodeIcon node.type)}}
                  </span>
                  <span class="assistant-workflow-preview__node-copy">
                    <strong title={{node.name}}>{{node.name}}</strong>
                    <small>{{node.type}}</small>
                    {{#if (this.nodeConnections node)}}
                      <span class="sr-only">
                        {{i18n
                          "discourse_workflows.admin_assistant.preview.connects_to"
                          nodes=(this.nodeConnections node)
                        }}
                      </span>
                    {{/if}}
                  </span>
                </article>
              {{/each}}
            </div>
          </div>
        {{else}}
          <p class="assistant-workflow-preview__fallback">
            {{i18n "discourse_workflows.admin_assistant.preview.unavailable"}}
          </p>
        {{/if}}
        <details class="assistant-workflow-preview__details">
          <summary class="assistant-workflow-preview__footer">
            {{#if this.layout}}
              <span class="assistant-workflow-preview__counts">
                {{i18n
                  "discourse_workflows.admin_assistant.preview.node_count"
                  count=this.preview.nodes.length
                }}
                ·
                {{i18n
                  "discourse_workflows.admin_assistant.preview.connection_count"
                  count=this.preview.connections.length
                }}
                {{#if this.layout.hasCycle}}
                  <span>
                    {{dIcon "arrow-rotate-right"}}
                    {{i18n "discourse_workflows.admin_assistant.preview.cycle"}}
                  </span>
                {{/if}}
              </span>
            {{/if}}
            <span class="assistant-workflow-preview__details-label">
              {{dIcon "caret-right"}}
              {{i18n
                "discourse_workflows.admin_assistant.preview.exact_configuration"
              }}
            </span>
          </summary>
          <pre><code>{{this.exactConfiguration}}</code></pre>
        </details>
      </section>
    {{/if}}
  </template>
}
